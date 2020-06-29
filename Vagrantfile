Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.box_version = "14.04"
  config.vm.synced_folder ".", "/vagrant"

  config.vm.provision "ansible_local" do |ansible|
    ansible.compatibility_mode = '2.0'
    ansible.limit = 'all'
    ansible.inventory_path = 'hosts'
    ansible.playbook = 'cgroup-setup.yml'
    ansible.extra_vars = { ansible_python_interpreter:"/usr/bin/python2" }
  end

end