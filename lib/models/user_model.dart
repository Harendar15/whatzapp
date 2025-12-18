// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String name;
  final String profilePic;
  final String phoneNumber;
  final String about;
  final bool isOnline;

  UserModel({
    required this.uid,
    required this.name,
    required this.profilePic,
    required this.phoneNumber,
    this.about = '',
    this.isOnline = false,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? profilePic,
    String? phoneNumber,
    String? about,
    bool? isOnline,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      profilePic: profilePic ?? this.profilePic,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      about: about ?? this.about,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'profilePic': profilePic,
      'phoneNumber': phoneNumber,
      'about': about,
      'isOnline': isOnline,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      profilePic: map['profilePic']?.toString() ??
          map['photoUrl']?.toString() ??
          map['avatar']?.toString() ??
          '',
      phoneNumber: map['phoneNumber']?.toString() ??
          map['phone']?.toString() ??
          '',
      about: map['about']?.toString() ?? map['status']?.toString() ?? '',
      isOnline: (map['isOnline'] is bool)
          ? map['isOnline']
          : ((map['online'] is bool) ? map['online'] : false),
    );
  }
}
