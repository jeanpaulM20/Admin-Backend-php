import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../models/client.dart';
import 'client_detail_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Client> _filterClients(List<Client> clients) {
    if (_searchQuery.isEmpty) return clients;
    final query = _searchQuery.toLowerCase();
    return clients.where((c) {
      return c.name.toLowerCase().contains(query) ||
          (c.email?.toLowerCase().contains(query) ?? false) ||
          (c.phone?.contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final trainerProvider = context.watch<TrainerProvider>();
    final authProvider = context.watch<AuthProvider>();
    final filteredClients = _filterClients(trainerProvider.clients);

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final trainer = authProvider.trainer;
              if (trainer != null) {
                await trainerProvider.fetchClients();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildContent(trainerProvider, filteredClients),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search clients...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildContent(TrainerProvider provider, List<Client> clients) {
    if (provider.clientsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8B2020),
          strokeWidth: 2,
        ),
      );
    }

    if (provider.clientsError != null) {
      return _buildError(provider.clientsError!);
    }

    if (clients.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchClients();
      },
      color: const Color(0xFF8B2020),
      backgroundColor: const Color(0xFF2a2a2a),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: clients.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 72, color: Color(0xFF2E2E2E)),
        itemBuilder: (context, index) {
          return _ClientTile(client: clients[index]);
        },
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF8B2020), size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9E9E9E)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<TrainerProvider>().fetchClients(),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 44),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: Color(0xFF555555), size: 48),
            const SizedBox(height: 16),
            Text(
              'No clients found for "$_searchQuery"',
              style: const TextStyle(color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: Color(0xFF555555), size: 60),
          SizedBox(height: 16),
          Text(
            'No clients yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your client list will appear here',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;

  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(),
      title: Text(
        client.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: _buildSubtitle(),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF555555),
        size: 20,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientDetailScreen(client: client),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    if (client.photo != null && client.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF333333),
        backgroundImage: NetworkImage(client.photo!),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF8B2020).withAlpha(40),
      child: Text(
        client.initials,
        style: const TextStyle(
          color: Color(0xFFB03030),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (client.email != null) parts.add(client.email!);
    if (client.phone != null && parts.isEmpty) parts.add(client.phone!);
    if (client.trainingType != null) parts.add(client.trainingType!);

    if (parts.isEmpty) return null;

    return Text(
      parts.first,
      style: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 13,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
