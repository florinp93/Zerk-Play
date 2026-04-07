import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../core/emby/models/emby_item.dart';
import '../../l10n/l10n.dart';
import 'item_details_page.dart';
import 'login_page.dart';

enum LibraryTab { movies, shows }

final class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell> {
  LibraryTab _tab = LibraryTab.movies;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.logout,
            onPressed: () async {
              await services.janus.logout();
              await services.artemis.clearSession();
              if (!context.mounted) return;
              await Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) {
              setState(() => _tab = LibraryTab.values[index]);
            },
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.movie_outlined),
                selectedIcon: Icon(Icons.movie),
                label: Text(l10n.movies),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tv_outlined),
                selectedIcon: Icon(Icons.tv),
                label: Text(l10n.shows),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _LibraryList(
              tab: _tab,
              onTapItem: (item) async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailsPage(itemId: item.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _LibraryList extends StatelessWidget {
  const _LibraryList({required this.tab, required this.onTapItem});

  final LibraryTab tab;
  final void Function(EmbyItem item) onTapItem;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final future = tab == LibraryTab.movies
        ? services.hermes.getMovies()
        : services.hermes.getShows();

    return FutureBuilder<List<EmbyItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }

        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(child: Text(context.l10n.noItemsFound));
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            final imageUri = services.hermes.primaryImageUri(item, maxWidth: 96);
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  imageUri.toString(),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 64,
                    height: 64,
                    child: ColoredBox(color: Colors.black12),
                  ),
                ),
              ),
              title: Text(item.name),
              subtitle: item.productionYear == null ? null : Text('${item.productionYear}'),
              onTap: () => onTapItem(item),
            );
          },
        );
      },
    );
  }
}
