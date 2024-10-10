import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/components/app/routebody/nomo_route_body.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/shimmer.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:zeniq_swap_frontend/widgets/swap/swap_widget.dart';

class SwappingScreen extends StatelessWidget {
  const SwappingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: NomoRouteBody(
        maxContentWidth: 480,
        padding: EdgeInsets.zero,
        child: TapIgnoreDragDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: TextFieldTapRegion(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  32.vSpacing,
                  SwapWidget(),
                  MediaQuery.of(context).viewInsets.bottom.vSpacing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
