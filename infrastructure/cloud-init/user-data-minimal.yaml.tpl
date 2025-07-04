#cloud-config
users:
  - name: testuser
    lock_passwd: false
    ssh_pwauth: true
    sudo: ALL=(ALL) NOPASSWD:ALL
ssh_pwauth: true
chpasswd:
  expire: false
  users:
    - name: testuser
      password: testpass123
      type: text
