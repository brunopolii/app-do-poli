
import 'package:flutter/material.dart';
import '../widgets/app_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Olá! 👋',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        const Text('Tudo do seu dia em um só lugar.'),
        const SizedBox(height: 18),
        const AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.today)),
            title: Text('Hoje'),
            subtitle: Text('Confira sua agenda, treino, alimentação e finanças.'),
          ),
        ),
        const AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.fitness_center)),
            title: Text('Academia'),
            subtitle: Text('Registre seus exercícios e cargas.'),
          ),
        ),
        const AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.restaurant)),
            title: Text('Alimentação'),
            subtitle: Text('Acompanhe calorias e macronutrientes.'),
          ),
        ),
      ],
    );
  }
}
