import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StudyBoardFooter extends StatelessWidget {
  final String title;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? ownerId;
  final bool isDark;

  const StudyBoardFooter({
    super.key,
    required this.title,
    required this.ownerName,
    required this.ownerAvatarUrl,
    required this.ownerId,
    required this.isDark,
  });

  void _navigateToAuthorProfile(BuildContext context) {
    if (ownerId == null) return;

    final queryParams = <String, String>{};
    if (ownerName != null) queryParams['name'] = ownerName!;
    if (ownerAvatarUrl != null) queryParams['avatar'] = ownerAvatarUrl!;

    context.pushNamed(
      'user-profile',
      pathParameters: {'userId': ownerId!},
      queryParameters: queryParams,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Avatar + Creator name
          Row(
            children: [
              _buildAvatar(context),
              const SizedBox(width: 8),
              if (ownerName != null)
                Expanded(
                  child: GestureDetector(
                    onTap: ownerId != null ? () => _navigateToAuthorProfile(context) : null,
                    child: Text(
                      ownerName!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // Row 2: Opening/Study name
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return GestureDetector(
      onTap: ownerId != null ? () => _navigateToAuthorProfile(context) : null,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
        child: ownerAvatarUrl != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: ownerAvatarUrl!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Icon(
                    Icons.person,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              )
            : Icon(
                Icons.person,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
      ),
    );
  }

}
