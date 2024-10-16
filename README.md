# UniswapV2 Frontend

Flutter web application for [Zeniq Swap](https://zeniq.dev/docs/swap/zeniqSwapOverview).  
Using [Walletkit-Dart](https://github.com/nomo-app/walletkit-dart).  
Supports both Metamask as well as Nomo App.

Supports Compiling to Web Assembly.  

## Get started

Run the following commands for a local dev setup:

````
git submodule update --init --recursive  
flutter pub get  
flutter run -d chrome  
````


https://github.com/Uniswap/sdks/blob/30b98e09d0486cd5cc3e4360e3277eb7cb60d2d5/sdks/sdk-core/src/utils/computePriceImpact.ts#L9


TODO:
Update PairInfo after providing/removing liquidity: Tomorrow
Remove Liqudity for legacy only allow removing all: Tomorrow
Fix Routing (Url parameters): Tomorrow
Update UI Pools Page: Tomorrow

Deploy with env variable 
QR Code Deeplink on WebStart