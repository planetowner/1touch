import 'package:flutter/material.dart';

var darktheme = ThemeData(
  scaffoldBackgroundColor: Color(0xFF090A0A), // Makes the home background black
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.black12, // Bottom navigation bar background
    elevation: 2,
    selectedItemColor: Colors.white, // Selected item color
    unselectedItemColor: Colors.white, // Unselected item color
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.black, // AppBar background
    elevation: 2,
    iconTheme: IconThemeData(color: Colors.white), // Icon color in AppBar
    // titleTextStyle: TextStyle(color: Colors.white, fontSize: 20), // Title text style
  ),
);

var whitetheme = ThemeData(
  scaffoldBackgroundColor: Colors.white, // Makes the home background black
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white, // Bottom navigation bar background
    elevation: 2,
    selectedItemColor: Colors.black, // Selected item color
    unselectedItemColor: Colors.black, // Unselected item color
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white, // AppBar background
    elevation: 2,
    iconTheme: IconThemeData(color: Colors.black), // Icon color in AppBar
    // titleTextStyle: TextStyle(color: Colors.white, fontSize: 20), // Title text style
  ),
);
