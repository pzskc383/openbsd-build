Vagrant.require_version '>= 1.1.0'

Vagrant.configure(2) do |config|
  config.ssh.shell = '/bin/ksh -l'
  config.ssh.sudo_command = 'doas %c'

  config.nfs.verify_installed = false
  config.vm.synced_folder '.', '/vagrant', disabled: true
  
  config.vm.provider :libvirt do |libvirt|
    libvirt.machine_type = 'q35'
    libvirt.disk_bus = 'virtio'
    libvirt.disk_driver :cache => 'none', :io => 'native'
    libvirt.memballoon_enabled = false

    libvirt.clock_timer :name => 'rtc', :tickpolicy => 'catchup'
    libvirt.clock_timer :name => 'pit', :tickpolicy => 'delay'
    libvirt.clock_timer :name => 'hpet', :present => 'yes'
    libvirt.clock_timer :name => 'kvmclock', :present => 'yes'

    libvirt.features = ['acpi', 'apic', 'pae', 'vmport state=off' ]
  end
end
