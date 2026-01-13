Vagrant.require_version '>= 1.1.0'

Vagrant.configure(2) do |config|
  config.ssh.shell = '/bin/ksh -l'
  config.ssh.sudo_command = 'doas %c'

  config.nfs.verify_installed = false
  config.vm.synced_folder '.', '/vagrant', disabled: true
end
