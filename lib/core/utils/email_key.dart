String emailKey(String email) =>
    email.trim().toLowerCase().replaceAll('.', ',');
