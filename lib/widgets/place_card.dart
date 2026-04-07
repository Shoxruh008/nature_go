import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/location_service.dart';
import 'favourite_button.dart';
import 'star_rating.dart';

class PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final Position? userPos;
  final VoidCallback onTap;

  const PlaceCard({
    super.key,
    required this.place,
    required this.userPos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pt = place.placeType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (place.images.isNotEmpty)
                      kIsWeb
                          ? Image.network(
                        place.images.first,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                        progress == null
                            ? child
                            : Container(color: pt.bg),
                        errorBuilder: (_, __, ___) => Container(
                          color: pt.bg,
                          child: Center(
                            child: Text(pt.icon,
                                style: const TextStyle(fontSize: 40)),
                          ),
                        ),
                      )
                          : CachedNetworkImage(
                        imageUrl: place.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: pt.bg),
                        errorWidget: (_, __, ___) => Container(
                          color: pt.bg,
                          child: Center(
                            child: Text(pt.icon,
                                style: const TextStyle(fontSize: 40)),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: pt.bg,
                        child: Center(
                          child: Text(pt.icon,
                              style: const TextStyle(fontSize: 40)),
                        ),
                      ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8, left: 8,
                      child: Wrap(
                        spacing: 4,
                        children: place.seasonTypes.map((s) {
                          final color = kSeasonColors[s] ?? AppTheme.primary;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              kSeasonUz[s] ?? s,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FavouriteButton(
                            placeId: place.id,
                            size: 32,
                            dark: true,
                          ),
                          if (place.distanceTo != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                LocationService.instance
                                    .formatDistance(place.distanceTo!),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: pt.color.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${pt.icon} ${pt.label}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          place.region,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StarRating(rating: place.baseRating, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        place.baseRating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMain),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}