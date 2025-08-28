import 'package:flutter/material.dart';
import 'package:animated_button/animated_button.dart';

//funcao chamada quando botao identificar for clicado 
void identificar_expsoicao() {



}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.green,
            alignment: Alignment.center,
            child: const Text("Página principal"),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 120, //altura do botao na tela
            child: Center(
              child: AnimatedButton(
                borderRadius: 25, 
                color: Colors.blue,
                shadowDegree: ShadowDegree.light,
                onPressed: identificar_expsoicao,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Identificar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
