// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IExchangeRouter {
    struct CreateOrderParamsAddresses {
        address receiver;
        address cancellationReceiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialCollateralToken;
        address[] swapPath;
    }

    struct CreateOrderParamsNumbers {
        uint256 sizeDeltaUsd;
        uint256 initialCollateralDeltaAmount;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 callbackGasLimit;
        uint256 minOutputAmount;
        uint256 validFromTime;
    }

    struct CreateOrderParams {
        CreateOrderParamsAddresses addresses;
        CreateOrderParamsNumbers numbers;
        uint8 orderType;
        uint8 decreasePositionSwapType;
        bool isLong;
        bool shouldUnwrapNativeToken;
        bool autoCancel;
        bytes32 referralCode;
    }

    function createOrder(CreateOrderParams memory params) external payable returns (bytes32);

    function sendTokens(address token, address receiver, uint256 amount) external;

    function sendWnt(address receiver, uint256 amount) external payable;
}

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

contract ShortTest is Test {
    address public wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // GMX
    address public exchangeRouter = 0x900173A66dbD345006C51fA35fA3aB760FcD843b;
    address public orderVault = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address public router = 0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6;
    address public dataStore = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;
    address public reader = 0xf60becbba223EEA9495Da3f606753867eC10d139;

    function setUp() public {
        vm.createSelectFork("https://arb-mainnet.g.alchemy.com/v2/Ea4M-V84UObD22z2nNlwDD9qP8eqZuSI", 301883180);

        deal(wbtc, address(this), 10e8);
    }

    function test_short() public {
        uint256 executionFee = 75826647000000;

        // send wnt sebesar 75826647000000 atau executionFee
        IExchangeRouter(exchangeRouter).sendWnt{value: executionFee}(orderVault, executionFee);

        // send token
        IERC20(wbtc).approve(router, 1e8);
        IExchangeRouter(exchangeRouter).sendTokens(wbtc, orderVault, 1e8);

        // tentukan swapPaths
        address[] memory swapPaths = new address[](1);
        swapPaths[0] = 0xcaCb964144f9056A8f99447a303E60b4873Ca9B4;

        // convert to sizeDeltaUsd
        // jumlah BTC * leverage * 35 decimals / decimalnya BTC
        uint256 sizeDeltaUsd = 1e8 * 2 * 1e35 / 1e8;

        IExchangeRouter.CreateOrderParams memory params = IExchangeRouter.CreateOrderParams({
            addresses: IExchangeRouter.CreateOrderParamsAddresses({
                receiver: address(this),
                cancellationReceiver: address(0),
                callbackContract: address(0),
                uiFeeReceiver: 0xff00000000000000000000000000000000000001,
                market: 0x47c031236e19d024b42f8AE6780E44A573170703,
                initialCollateralToken: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
                swapPath: swapPaths
            }),
            numbers: IExchangeRouter.CreateOrderParamsNumbers({
                sizeDeltaUsd: sizeDeltaUsd,
                initialCollateralDeltaAmount: 0,
                triggerPrice: 0,
                acceptablePrice: 0,
                executionFee: executionFee,
                callbackGasLimit: 0,
                minOutputAmount: 0,
                validFromTime: 0
            }),
            orderType: 2,
            decreasePositionSwapType: 0,
            isLong: false,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: bytes32(0)
        });

        bytes32 positionId = IExchangeRouter(exchangeRouter).createOrder(params);
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
