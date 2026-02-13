import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/domain/models/user_model.dart';

class UsersNotifier extends StateNotifier<List<UserModel>> {
  UsersNotifier() : super([]) {
    loadUsers();
  }

  void loadUsers() {
    state = _getDummyUsers();
  }

  List<UserModel> _getDummyUsers() {
    return [
      UserModel(
        id: '9',
        name: 'Jai Patel',
        avatar: '👨‍💻',
        status: 'Available',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=12',
      ),
      UserModel(
        id: '10',
        name: 'Shon Puri',
        avatar: '👨‍💼',
        status: 'In discussion',
        isOnline: false,
        lastSeen: '1 hour ago',
        profilePicture: 'https://i.pravatar.cc/150?img=13',
      ),
      UserModel(
        id: '11',
        name: 'Nishant',
        avatar: '👨‍🔧',
        status: 'Working remotely',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=14',
      ),
      UserModel(
        id: '12',
        name: 'Achal Jain',
        avatar: '👨‍📊',
        status: 'Available for meeting',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=15',
      ),
      UserModel(
        id: '13',
        name: 'Anurag Tiwari',
        avatar: '👨‍💻',
        status: 'Building Flutter apps',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=33',
      ),
      UserModel(
        id: '14',
        name: 'Rutik',
        avatar: '👨‍🎯',
        status: 'Focused mode',
        isOnline: false,
        lastSeen: '3 hours ago',
        profilePicture: 'https://i.pravatar.cc/150?img=51',
      ),
      UserModel(
        id: '15',
        name: 'Dhruv',
        avatar: '👨‍🚀',
        status: 'Exploring ideas',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=52',
      ),
      UserModel(
        id: '16',
        name: 'Viral',
        avatar: '👨‍💼',
        status: 'In office',
        isOnline: false,
        lastSeen: '45 minutes ago',
        profilePicture: 'https://i.pravatar.cc/150?img=56',
      ),
      UserModel(
        id: '17',
        name: 'Jainesh',
        avatar: '👨‍📚',
        status: 'Learning new tech',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=59',
      ),
      UserModel(
        id: '18',
        name: 'Khushi',
        avatar: '👩‍🎓',
        status: 'Available',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=47',
      ),
      UserModel(
        id: '19',
        name: 'Riya Bhariya',
        avatar: '👩‍💻',
        status: 'Designing UI',
        isOnline: false,
        lastSeen: '2 hours ago',
        profilePicture: 'https://i.pravatar.cc/150?img=45',
      ),
      UserModel(
        id: '20',
        name: 'Chirag Shah',
        avatar: '👨‍💻',
        status: 'Code review',
        isOnline: true,
        profilePicture: 'https://i.pravatar.cc/150?img=68',
      ),
    ];
  }
}

final usersProvider = StateNotifierProvider<UsersNotifier, List<UserModel>>(
  (ref) => UsersNotifier(),
);
