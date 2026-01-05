Vagrant.require_version '>= 1.1.0'

Vagrant.configure(2) do |config|
  config.ssh.shell = 'ksh'
  config.ssh.sudo_command = 'doas %c'

  config.vm.synced_folder '.', '/vagrant', disabled: true
end
