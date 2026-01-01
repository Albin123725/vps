{ pkgs, ... }: {
  channel = "stable-24.05";
  
  packages = [
    pkgs.qemu
    pkgs.qemu_kvm
    pkgs.git
    pkgs.bash
    pkgs.coreutils
    pkgs.wget
    pkgs.cloud-utils
    pkgs.cdrkit
  ];
  
  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    
    workspace.onStart = {
      welcome = "echo 'QEMU-freeroot ready! Run: ./vm.sh'";
    };
  };
}
