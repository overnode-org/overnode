#
# License: https://github.com/webintrinsics/cluster-formation/blob/master/LICENSE
#

#
# assert vagrant setup
#
Vagrant.require_version '>= 1.8.6', '!= 1.8.5'
def validate_plugins
  required_plugins = [
    'vagrant-hostmanager',
    'vagrant-proxyconf'
  ]
  missing_plugins = []

  required_plugins.each do |plugin|
    unless Vagrant.has_plugin?(plugin)
      missing_plugins << "The '#{plugin}' plugin is required. Install it with 'vagrant plugin install #{plugin}'"
    end
  end

  unless missing_plugins.empty?
    missing_plugins.each { |x| STDERR.puts x }
    return false
  end

  true
end

validate_plugins || exit(17) # expected return code in build.sbt for missing plugins

#
# Provision machines
#
Vagrant.configure(2) do |config|
    config.vm.define "clusterlite-build" do |s|
        s.vm.box = "bento/ubuntu-16.04"
        s.vm.synced_folder "./", "/vagrant"
        s.ssh.forward_agent = true

        #
        # configure networking for VM
        #
        s.vm.hostname = "clusterlite-build"
        s.vm.network "private_network", ip: "192.168.52.11", netmask: "255.255.255.0", auto_config: true
        s.vm.provider "virtualbox" do |v|
            v.name = s.vm.hostname
            v.memory = 4096
            v.cpus = 4
            v.gui = false

            # disable DHCP client configuration for NAT interface
            v.auto_nat_dns_proxy = false
            v.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
            v.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
        end
        # configure proxy settings
        if ENV.has_key?('http_proxy') || ENV.has_key?('HTTP_PROXY')
            s.proxy.http = ENV['http_proxy'] || ENV['HTTP_PROXY']
            s.proxy.https = ENV['http_proxy'] || ENV['HTTP_PROXY']
        end
        if ENV.has_key?('https_proxy') || ENV.has_key?('HTTPS_PROXY')
            s.proxy.https = ENV['https_proxy'] || ENV['HTTPS_PROXY']
        end
        if ENV.has_key?('no_proxy') || ENV.has_key?('NO_PROXY')
            s.proxy.no_proxy = ENV['no_proxy'] || ENV['NO_PROXY']
        end

        #
        # for ubuntu install the fastest mirror
        # http://askubuntu.com/questions/39922/how-do-you-select-the-fastest-mirror-from-the-command-line
        #
        s.vm.provision :shell, inline: "cp /vagrant/mirror.list /etc/apt/sources.list.d/mirror.list"

        s.vm.provision :shell, inline: "/vagrant/build-machine.sh"
    end

    if Vagrant.has_plugin?("vagrant-cachier")
        config.cache.scope = :box
    end
end
