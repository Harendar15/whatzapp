import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeController extends GetxController
    with WidgetsBindingObserver, GetSingleTickerProviderStateMixin {

  RxInt selectIndex = 0.obs;
  late TabController tabController;

  @override
  void onInit() {
    super.onInit();

    tabController = TabController(length: 4, vsync: this);
    tabController.addListener(() {
      selectIndex.value = tabController.index;
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
