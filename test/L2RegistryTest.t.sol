// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/L2Registry.sol";
import "../src/L2Registrar.sol";

contract L2RegistryTest is Test {
    L2Registry public registry;
    L2Registrar public registrar;

    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    event Registered(string indexed label, address owner);
    event TextChanged(bytes32 indexed labelhash, string key, string value);
    event AddrChanged(bytes32 indexed labelhash, uint256 coinType, bytes value);

    function setUp() public {
        // Deploy registry with test parameters
        vm.startPrank(admin);
        registry = new L2Registry("TestNames", "TEST", "https://test.uri/");

        // Deploy registrar
        registrar = new L2Registrar(IL2Registry(address(registry)));

        // Grant registrar role to registrar contract
        registry.addRegistrar(address(registrar));

        // Set name price
        registrar.setPrice(0.01 ether);
        vm.stopPrank();
    }

    function test_RegisterName() public {
        string memory label = "test";
        bytes32 expectedLabelhash = keccak256(abi.encodePacked(label));

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        registrar.register{value: 0.01 ether}(label, user1);

        assertEq(registry.ownerOf(uint256(expectedLabelhash)), user1);
    }

    function test_SetRecords() public {
        // First register a name
        string memory label = "test";
        bytes32 labelhash = keccak256(abi.encodePacked(label));

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        registrar.register{value: 0.01 ether}(label, user1);

        // Prepare record data
        L2Registry.Text[] memory texts = new L2Registry.Text[](1);
        texts[0] = L2Registry.Text({key: "email", value: "test@example.com"});

        L2Registry.Addr[] memory addrs = new L2Registry.Addr[](1);
        addrs[0] = L2Registry.Addr({
            coinType: 60, // ETH
            value: abi.encodePacked(user2)
        });

        bytes memory contenthash = hex"1234";

        // Set records
        vm.expectEmit(true, false, false, true);
        emit TextChanged(labelhash, "email", "test@example.com");

        registry.setRecords(labelhash, texts, addrs, contenthash);
        vm.stopPrank();

        // Verify records
        assertEq(registry.text(labelhash, "email"), "test@example.com");
        assertEq(registry.addr(labelhash), user2);
    }

    function test_AccessControl() public {
        // Test admin functions
        vm.prank(user1);
        vm.expectRevert();
        registry.addRegistrar(user2);

        vm.prank(admin);
        registry.addRegistrar(user2);

        // Test registrar functions
        vm.prank(user1);
        vm.expectRevert();
        registry.register("test", user1);
    }

    function testFuzz_RegisterName(string calldata label) public {
        vm.assume(bytes(label).length > 0);
        vm.assume(bytes(label).length < 100); // reasonable length limit

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        registrar.register{value: 0.01 ether}(label, user1);

        bytes32 labelhash = keccak256(abi.encodePacked(label));
        assertEq(registry.ownerOf(uint256(labelhash)), user1);
    }
}