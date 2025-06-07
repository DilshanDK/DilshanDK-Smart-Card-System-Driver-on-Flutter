import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_card_app_driver/auth_interfaces/authentication.dart';
import 'package:smart_card_app_driver/manage_interfaces/home_screen.dart';
import 'package:smart_card_app_driver/models/driver.dart';



class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<Driver?>(context);

    if (user != null) {
      return HomeScreen();
    }else{
      return Authentication();
    }
  }
}
