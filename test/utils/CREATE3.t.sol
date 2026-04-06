// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

// 用于测试的简单目标合约：无构造函数参数
contract SimpleContract {
    uint256 public value = 42;
}

// 用于测试的目标合约：带构造函数参数
contract ParameterizedContract {
    string public name;
    uint256 public value;

    constructor(string memory name_, uint256 value_) {
        name = name_;
        value = value_;
    }
}

// 用于测试的目标合约：带 payable 构造函数，可接收 ETH
contract PayableContract {
    uint256 public receivedValue;

    constructor() payable {
        receivedValue = msg.value;
    }
}

// 用于测试的目标合约：构造函数会 revert
contract RevertingContract {
    constructor() {
        revert("CONSTRUCTOR_REVERT");
    }
}

// 外部部署合约：library internal 函数内联到此合约中执行
// 用于 revert 测试（vm.expectRevert 只能捕获外部调用的 revert）以及跨合约地址预测测试
contract CREATE3Deployer {
    using CREATE3 for bytes32;

    function deploy(bytes32 salt, bytes memory creationCode, uint256 value) external payable returns (address) {
        return salt.deploy(creationCode, value);
    }

    function getDeployed(bytes32 salt) external view returns (address) {
        return salt.getDeployed();
    }

    receive() external payable {}
}

contract CREATE3Test is Test {
    using CREATE3 for bytes32;
    using Bytes32AddressLib for bytes32;

    CREATE3Deployer deployer = new CREATE3Deployer();

    /*//////////////////////////////////////////////////////////////
                             DEPLOY — HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    // 正向：部署无参数合约，验证返回地址有代码
    function testDeploySimpleContract() public {
        bytes32 salt = keccak256("simple");
        address deployed = salt.deploy(type(SimpleContract).creationCode, 0);

        assertTrue(deployed != address(0));
        assertTrue(deployed.code.length > 0);
        assertEq(SimpleContract(deployed).value(), 42);
    }

    // 正向：部署带构造函数参数的合约，验证参数被正确传递
    function testDeployParameterizedContract() public {
        bytes32 salt = keccak256("parameterized");
        bytes memory creationCode =
            abi.encodePacked(type(ParameterizedContract).creationCode, abi.encode("TestToken", uint256(100)));
        address deployed = salt.deploy(creationCode, 0);

        assertTrue(deployed.code.length > 0);
        assertEq(ParameterizedContract(deployed).name(), "TestToken");
        assertEq(ParameterizedContract(deployed).value(), 100);
    }

    // 正向：部署时附带 ETH，验证目标合约收到 ETH
    function testDeployWithValue() public {
        bytes32 salt = keccak256("payable");
        uint256 sendValue = 1 ether;

        address deployed = salt.deploy(type(PayableContract).creationCode, sendValue);

        assertTrue(deployed.code.length > 0);
        assertEq(PayableContract(deployed).receivedValue(), sendValue);
        assertEq(address(deployed).balance, sendValue);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPLOY — ADDRESS DETERMINISM
    //////////////////////////////////////////////////////////////*/

    // 核心：相同 salt 产生相同的预测地址
    function testDeployedAddressMatchesGetDeployed() public {
        bytes32 salt = keccak256("deterministic");
        address predicted = salt.getDeployed();
        address deployed = salt.deploy(type(SimpleContract).creationCode, 0);

        assertEq(deployed, predicted);
    }

    // 核心：不同 creationCode + 相同 salt → 相同地址（CREATE3 的核心特性）
    // 注：由于同一 salt 不能在同一 deployer 内部署两次（proxy 地址冲突），
    // 所以先部署第一个 bytecode，再用 vm.etch 清空 proxy 和最终合约的代码，
    // 然后用不同 bytecode 重新部署，验证两次部署地址一致
    function testSameSaltDifferentBytecodeSameAddress() public {
        bytes32 salt = keccak256("same-salt");

        // 第一次部署：SimpleContract
        address deployed1 = deployer.deploy(salt, type(SimpleContract).creationCode, 0);
        assertEq(SimpleContract(deployed1).value(), 42);

        // 计算 proxy 地址（CREATE2 公式：0xFF ++ deployer ++ salt ++ PROXY_BYTECODE_HASH）
        // 需要清空 proxy 代码，否则第二次 CREATE2 会因地址冲突而 revert
        bytes32 proxyBytecodeHash = keccak256(hex"67363d3d37363d34f03d5260086018f3");
        address proxy =
            keccak256(abi.encodePacked(bytes1(0xFF), address(deployer), salt, proxyBytecodeHash)).fromLast20Bytes();

        // 清空 proxy 和最终合约的代码
        vm.etch(proxy, "");
        vm.etch(deployed1, "");
        // 重置 proxy 的 nonce 为 0，这样下次 CREATE 时 nonce 回到 1
        vm.resetNonce(proxy);
        // 重置最终合约地址的 nonce，避免 CreateCollision
        // 注：
        // 1. 当一个合约被部署成功后，EVM 会将该地址的 nonce 设为 1（EIP-161）
        // 2. 如果被部署到目标合约地址满足以下任一条件，CREATE 失败，返回 address(0)（EIP-7610）：
        // - nonce > 0
        // - code.length > 0
        vm.resetNonce(deployed1);

        // 第二次部署：ParameterizedContract（不同的 creationCode）
        bytes memory creationCode2 =
            abi.encodePacked(type(ParameterizedContract).creationCode, abi.encode("Token", uint256(999)));
        address deployed2 = deployer.deploy(salt, creationCode2, 0);
        // 验证第二次部署的合约功能正常（确实是 ParameterizedContract）
        assertEq(ParameterizedContract(deployed2).name(), "Token");
        assertEq(ParameterizedContract(deployed2).value(), 999);

        // 核心断言：两次部署地址一致 —— 证明地址与 creationCode 无关
        assertEq(deployed1, deployed2);
    }

    // 核心：不同 salt → 不同地址
    function testDifferentSaltDifferentAddress() public view {
        bytes32 salt1 = keccak256("salt-1");
        bytes32 salt2 = keccak256("salt-2");

        address predicted1 = salt1.getDeployed();
        address predicted2 = salt2.getDeployed();

        assertTrue(predicted1 != predicted2);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPLOY — REVERT CASES
    //////////////////////////////////////////////////////////////*/

    // 反向：相同 salt 重复部署 → revert "DEPLOYMENT_FAILED"
    // 注：通过外部合约调用，vm.expectRevert 才能捕获 library 内部的 require revert
    function testRevertDoubleDeploy() public {
        bytes32 salt = keccak256("double");
        deployer.deploy(salt, type(SimpleContract).creationCode, 0);

        vm.expectRevert("DEPLOYMENT_FAILED");
        deployer.deploy(salt, type(SimpleContract).creationCode, 0);
    }

    // 反向：相同 salt 不同 bytecode 重复部署 → revert "DEPLOYMENT_FAILED"
    function testRevertDoubleDeployDifferentBytecode() public {
        bytes32 salt = keccak256("double-diff");
        deployer.deploy(salt, type(SimpleContract).creationCode, 0);

        bytes memory creationCode =
            abi.encodePacked(type(ParameterizedContract).creationCode, abi.encode("Token", uint256(1)));
        vm.expectRevert("DEPLOYMENT_FAILED");
        deployer.deploy(salt, creationCode, 0);
    }

    // 反向：构造函数 revert → revert "INITIALIZATION_FAILED"
    function testRevertConstructorReverts() public {
        bytes32 salt = keccak256("reverting");

        vm.expectRevert("INITIALIZATION_FAILED");
        deployer.deploy(salt, type(RevertingContract).creationCode, 0);
    }

    // 反向：空 creationCode → revert "INITIALIZATION_FAILED"
    function testRevertEmptyCreationCode() public {
        bytes32 salt = keccak256("empty");

        vm.expectRevert("INITIALIZATION_FAILED");
        deployer.deploy(salt, "", 0);
    }

    /*//////////////////////////////////////////////////////////////
                        GET DEPLOYED — ADDRESS PREDICTION
    //////////////////////////////////////////////////////////////*/

    // 正向：getDeployed(salt) 使用 address(this) 作为 creator
    function testGetDeployedUsesThisAsCreator() public view {
        bytes32 salt = keccak256("self");

        address fromSingleArg = salt.getDeployed();
        address fromTwoArgs = salt.getDeployed(address(this));

        assertEq(fromSingleArg, fromTwoArgs);
    }

    // 正向：不同 creator → 不同预测地址
    function testGetDeployedDifferentCreator() public pure {
        bytes32 salt = keccak256("creator");

        address addr1 = salt.getDeployed(address(0xA));
        address addr2 = salt.getDeployed(address(0xB));

        assertTrue(addr1 != addr2);
    }

    // 正向：从外部 deployer 部署，用 getDeployed(salt, deployer) 预测地址
    function testGetDeployedWithExternalDeployer() public {
        bytes32 salt = keccak256("external");

        // creator = deployer（因为 library 函数内联到 deployer 中执行）
        address predicted = salt.getDeployed(address(deployer));

        address deployed = deployer.deploy(salt, type(SimpleContract).creationCode, 0);

        assertEq(deployed, predicted);
    }

    // 正向：相同参数多次调用 getDeployed 返回一致结果（幂等性）
    function testGetDeployedIdempotent() public view {
        bytes32 salt = keccak256("idempotent");

        address first = salt.getDeployed();
        address second = salt.getDeployed();

        assertEq(first, second);
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // Fuzz：任意 salt 部署后地址与 getDeployed 预测一致
    function testFuzzDeployMatchesPrediction(bytes32 salt) public {
        address predicted = salt.getDeployed();
        address deployed = salt.deploy(type(SimpleContract).creationCode, 0);

        assertEq(deployed, predicted);
    }

    // Fuzz：任意 salt 的两个不同 creator 产生不同地址
    function testFuzzDifferentCreatorsDifferentAddresses(bytes32 salt, address creator1, address creator2) public pure {
        vm.assume(creator1 != creator2);

        address addr1 = salt.getDeployed(creator1);
        address addr2 = salt.getDeployed(creator2);

        assertTrue(addr1 != addr2);
    }

    // Fuzz：任意两个不同 salt 产生不同地址
    function testFuzzDifferentSaltsDifferentAddresses(bytes32 salt1, bytes32 salt2) public view {
        vm.assume(salt1 != salt2);

        address addr1 = salt1.getDeployed();
        address addr2 = salt2.getDeployed();

        assertTrue(addr1 != addr2);
    }
}
