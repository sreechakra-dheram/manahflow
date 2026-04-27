enum UserRole { siteEngineer, projectManager, finance }

class UserModel {
  final String id;
  final String name;
  final UserRole role;
  final String company;
  final String email;
  final String avatarInitials;

  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.company,
    required this.email,
    required this.avatarInitials,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        role: UserRole.values.firstWhere(
          (e) => e.toString() == json['role'],
          orElse: () => UserRole.siteEngineer,
        ),
        company: json['company'],
        email: json['email'],
        avatarInitials: json['avatarInitials'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.toString(),
        'company': company,
        'email': email,
        'avatarInitials': avatarInitials,
      };

  String get roleDisplayName {
    switch (role) {
      case UserRole.siteEngineer:
        return 'Site Engineer';
      case UserRole.projectManager:
        return 'Project Manager';
      case UserRole.finance:
        return 'Finance';
    }
  }

  bool get canApproveInvoice => role == UserRole.projectManager || role == UserRole.finance;
}

const List<UserModel> kUsers = [
  UserModel(
    id: 'u1',
    name: 'Site Engineer',
    role: UserRole.siteEngineer,
    company: 'ManahFlow',
    email: 'engineer@manahflow.com',
    avatarInitials: 'SE',
  ),
  UserModel(
    id: 'u2',
    name: 'Project Manager',
    role: UserRole.projectManager,
    company: 'ManahFlow',
    email: 'manager@manahflow.com',
    avatarInitials: 'PM',
  ),
  UserModel(
    id: 'u3',
    name: 'Finance Admin',
    role: UserRole.finance,
    company: 'ManahFlow',
    email: 'finance@manahflow.com',
    avatarInitials: 'FA',
  ),
];
