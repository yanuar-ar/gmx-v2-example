// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultShort} from "../src/VaultShort.sol";

interface IReaderOrder {
    struct Addresses {
        address account;
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialCollateralToken;
        address[] swapPath;
    }

    struct Numbers {
        uint8 orderType;
        uint8 decreasePositionSwapType;
        uint256 sizeDeltaUsd;
        uint256 initialCollateralDeltaAmount;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 callbackGasLimit;
        uint256 minOutputAmount;
        uint256 updatedAtBlock;
    }

    struct Flags {
        bool isLong;
        bool shouldUnwrapNativeToken;
        bool isFrozen;
    }

    struct Props {
        Addresses addresses;
        Numbers numbers;
        Flags flags;
    }

    function getOrder(address dataStore, bytes32 key) external view returns (Props memory);
}

interface IReaderPosition {
    struct Addresses {
        address account;
        address market;
        address collateralToken;
    }

    struct Numbers {
        uint256 sizeInUsd;
        uint256 sizeInTokens;
        uint256 collateralAmount;
        uint256 borrowingFactor;
        uint256 fundingFeeAmountPerSize;
        uint256 longTokenClaimableFundingAmountPerSize;
        uint256 shortTokenClaimableFundingAmountPerSize;
        uint256 increasedAtBlock;
        uint256 decreasedAtBlock;
    }

    struct Flags {
        bool isLong;
    }

    struct Props {
        Addresses addresses;
        Numbers numbers;
        Flags flags;
    }

    function getPosition(address dataStore, bytes32 key) external view returns (Props memory);
}

contract VaultShortTest is Test {
    address public wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    address public dataStore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address public reader = 0xf60becbba223EEA9495Da3f606753867eC10d139;

    VaultShort public vaultShort;

    function setUp() public {
        vm.createSelectFork("https://arb-mainnet.g.alchemy.com/v2/Ea4M-V84UObD22z2nNlwDD9qP8eqZuSI", 301883180);

        deal(wbtc, address(this), 10e8);
        vaultShort = new VaultShort();
    }

    function test_vault_short() public {
        uint256 executionFee = 75826647000000;

        IERC20(wbtc).approve(address(vaultShort), 1e8);
        bytes32 positionId = vaultShort.deposit{value: executionFee}(1e8);

        console.log("positionId:", vm.toString(positionId));

        IReaderOrder.Props memory order = IReaderOrder(reader).getOrder(dataStore, positionId);
        console.log("order.numbers.sizeDeltaUsd", order.numbers.sizeDeltaUsd);
        console.log("order.flags.isLong", order.flags.isLong);

        console.log("================");

        IReaderPosition.Props memory position = IReaderPosition(reader).getPosition(dataStore, positionId);
        console.log("position.numbers.sizeInUsd", position.numbers.sizeInUsd);
        console.log("position.flags.isLong", position.flags.isLong);
    }
}
