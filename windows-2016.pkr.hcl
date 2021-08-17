packer {
  required_plugins {
    windows-update = {
      version = "0.14.0"
      source = "github.com/rgl/windows-update"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "61440"
}

variable "iso_url" {
  type    = string
  default = "https://software-download.microsoft.com/download/pr/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:1ce702a578a3cb1ac3d14873980838590f06d5b7101c5daaccbac9d73f1fb50f"
}

variable "hyperv_switch_name" {
  type    = string
  default = env("HYPERV_SWITCH_NAME")
}

variable "hyperv_vlan_id" {
  type    = string
  default = env("HYPERV_VLAN_ID")
}

variable "vagrant_box" {
  type = string
}

source "qemu" "windows-2016-amd64" {
  accelerator = "kvm"
  cpus        = 2
  memory      = 6144
  qemuargs = [
    ["-cpu", "host"],
    ["-soundhw", "hda"],
    ["-device", "piix3-usb-uhci"],
    ["-device", "usb-tablet"],
    ["-device", "virtio-net,netdev=user.0"],
    ["-vga", "qxl"],
    ["-device", "virtio-serial-pci"],
    ["-chardev", "socket,path=/tmp/{{ .Name }}-qga.sock,server,nowait,id=qga0"],
    ["-device", "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"],
    ["-chardev", "spicevmc,id=spicechannel0,name=vdagent"],
    ["-device", "virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"],
    ["-spice", "unix,addr=/tmp/{{ .Name }}-spice.socket,disable-ticketing"],
  ]
  disk_interface = "virtio"
  disk_size      = var.disk_size
  floppy_files = [
    "windows-2016/autounattend.xml",
    "winrm.ps1",
    "provision-openssh.ps1",
    "drivers/vioserial/2k16/amd64/*.cat",
    "drivers/vioserial/2k16/amd64/*.inf",
    "drivers/vioserial/2k16/amd64/*.sys",
    "drivers/viostor/2k16/amd64/*.cat",
    "drivers/viostor/2k16/amd64/*.inf",
    "drivers/viostor/2k16/amd64/*.sys",
    "drivers/NetKVM/2k16/amd64/*.cat",
    "drivers/NetKVM/2k16/amd64/*.inf",
    "drivers/NetKVM/2k16/amd64/*.sys",
    "drivers/qxldod/2k16/amd64/*.cat",
    "drivers/qxldod/2k16/amd64/*.inf",
    "drivers/qxldod/2k16/amd64/*.sys",
  ]
  format           = "qcow2"
  headless         = true
  http_directory   = "."
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  shutdown_command = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator     = "ssh"
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "4h"
}

source "virtualbox-iso" "windows-2016-amd64" {
  cpus      = 2
  memory    = 6144
  disk_size = var.disk_size
  floppy_files = [
    "windows-2016/autounattend.xml",
    "winrm.ps1",
    "provision-openssh.ps1",
  ]
  guest_additions_interface = "sata"
  guest_additions_mode      = "attach"
  guest_os_type             = "Windows2016_64"
  hard_drive_interface      = "sata"
  headless                  = true
  iso_url                   = var.iso_url
  iso_checksum              = var.iso_checksum
  iso_interface             = "ide"
  shutdown_command          = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--vrde", "off"],
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vboxsvga"],
    ["modifyvm", "{{ .Name }}", "--vram", "128"],
    ["modifyvm", "{{ .Name }}", "--accelerate3d", "on"],
    ["modifyvm", "{{ .Name }}", "--usb", "on"],
    ["modifyvm", "{{ .Name }}", "--mouse", "usbtablet"],
    ["modifyvm", "{{ .Name }}", "--audio", "none"],
    ["modifyvm", "{{ .Name }}", "--nictype1", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype2", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype3", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype4", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nested-hw-virt", "on"],
  ]
  communicator = "ssh"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout  = "4h"
}

source "hyperv-iso" "windows-2016-amd64" {
  cpus         = 2
  memory       = 6144
  generation   = 2
  boot_command = ["<up><wait><up><wait><up><wait><up><wait><up><wait>"]
  boot_order   = ["SCSI:0:0"]
  boot_wait    = "1s"
  cd_files = [
    "windows-2016-uefi/autounattend.xml",
    "winrm.ps1",
    "provision-openssh.ps1",
  ]
  disk_size         = var.disk_size
  first_boot_device = "DVD"
  headless          = true
  iso_url           = var.iso_url
  iso_checksum      = var.iso_checksum
  switch_name       = var.hyperv_switch_name
  temp_path         = "tmp"
  vlan_id           = var.hyperv_vlan_id
  shutdown_command  = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator      = "ssh"
  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_timeout       = "4h"
}

build {
  sources = [
    "source.qemu.windows-2016-amd64",
    "source.virtualbox-iso.windows-2016-amd64",
    "source.hyperv-iso.windows-2016-amd64",
  ]

  provisioner "powershell" {
    script = "disable-windows-updates.ps1"
  }

  provisioner "powershell" {
    inline = ["Uninstall-WindowsFeature Windows-Defender-Features"]
  }

  provisioner "powershell" {
    inline = ["Uninstall-WindowsFeature FS-SMB1"]
  }

  provisioner "powershell" {
    only   = ["virtualbox-iso.windows-2016-amd64"]
    script = "virtualbox-prevent-vboxsrv-resolution-delay.ps1"
  }

  provisioner "powershell" {
    only   = ["qemu.windows-2016-amd64"]
    script = "provision-guest-tools-qemu-kvm.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    only   = ["qemu.windows-2016-amd64"]
    script = "libvirt-fix-cpu-driver.ps1"
  }

  provisioner "powershell" {
    script = "provision.ps1"
  }

  provisioner "windows-update" {
    filters = [
      "include:$_.Title -like '*Servicing Stack Update for Windows*'",
    ]
  }

  provisioner "windows-update" {
  }

  provisioner "powershell" {
    script = "enable-remote-desktop.ps1"
  }

  provisioner "powershell" {
    script = "provision-cloudbase-init.ps1"
  }

  provisioner "powershell" {
    script = "ConfigureRemotingForAnsible.ps1"
  }

  provisioner "powershell" {
    script = "01-install-docker.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    script = "02-install-docker.ps1"
  }

  provisioner "powershell" {
    script = "eject-media.ps1"
  }

  provisioner "powershell" {
    script = "optimize.ps1"
  }

  post-processor "vagrant" {
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile.template"
  }
}
