import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart'; // Moteur Vidéo
import 'player_screen.dart'; // C'est ici que se trouve ton nouveau Dashboard

void main() {
  // Initialisation obligatoire du moteur vidéo avant le lancement
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); 

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Master Pro',
      
      // Configuration visuelle (Mode Sombre Pro)
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212), // Fond noir profond
        
        // Palette de couleurs unifiée
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.blueAccent,
          surface: Color(0xFF1E1E1E),
        ),
        
        // Style global des boutons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
      
      // C'est la ligne la plus importante :
      // On ne lance plus HomeScreen, mais ton nouveau Dashboard unifié
      home: const IptvDashboard(),
    );
  }
}