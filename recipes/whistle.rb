#
# Cookbook Name:: freeswitch
# Recipe:: whistle
#
# Copyright 2011, 2600hz 
#

include_recipe "bluepill"

opensips = data_bag('accounts')

packages = value_for_platform(
	[ "centos", "redhat", "fedora", "suse", "amazon" ] => {
	  "default" => %w(curl unzip mysql-server ncurses-devel ncurses-devel e2fsprogs-libs glibc libgcrypt openssl openssl-devel zlib zlib-devel libgcc libogg libogg-devel libidn libstdc++ libjpeg postgresql-libs gnutls gnutls-devel expat-devel libtiff libtiff-devel libtheora libtheora-devel alsa-lib alsa-lib-devel unixODBC unixODBC-devel libvorbis libvorbis-devel flite)
	},
	[ "ubuntu", "debian"] => {
	  "default" => %w( libasound2  libogg0 libvorbis0a autoconf libncurses5-dev debconf-utils vim unixODBC strace unixODBC-dev libtiff4 libtiff4-dev libtool)
	},
	"default" => %w{libtiff libtiff-devel libtheora libtheora-devel alsa-lib alsa-lib-devel unixODBC unixODBC-devel libvorbis libvorbis-devel}
)

packages.each do |pkg|
	package pkg do
	  action :install
	end
end

case node[:platform]
when "debian", "ubuntu"

  script "install_freeswitch" do
    not_if { ::FileTest.exists?("/opt/freeswitch/bin/fs_cli") }
    interpreter "bash"
    user "root"
    cwd "/usr/src"
    code <<-EOH
		cd /usr/src
		wget http://hudson.2600hz.org/freeswitch-latest-amd64.deb
		wget http://hudson.2600hz.org/freeswitch-lang-en-latest-amd64.deb
		dpkg -i /usr/src/freeswitch-latest-amd64.deb
		dpkg -i /usr/src/freeswitch-lang-en-latest-amd64.deb
		chown -R freeswitch:daemon /opt/freeswitch
    EOH
  end

  template "/etc/default/freeswitch" do
    source "freeswitch.erb"
    owner "root"
    group "root"
    mode 0644
  end

  template "/etc/init.d/freeswitch" do
    source "freeswitch-init.erb"
    owner "root"
    group "root"
    mode 0755
  end

when "centos", "redhat", "fedora", "amazon"
  %w{
    freeswitch-application-abstraction
    freeswitch-application-avmd
    freeswitch-application-conference
    freeswitch-application-curl
    freeswitch-application-fsv
    freeswitch-application-hash
    freeswitch-application-httapi
    freeswitch-application-http-cache
    freeswitch-application-sms
    freeswitch-application-snapshot
    freeswitch-application-snom
    freeswitch-application-soundtouch
    freeswitch-application-spy
    freeswitch-application-stress
    freeswitch-application-valet_parking
    freeswitch-asrtts-flite
    freeswitch-codec-bv
    freeswitch-codec-celt
    freeswitch-codec-codec2
    freeswitch-codec-h26x
    freeswitch-codec-ilbc
    freeswitch-codec-isac
    freeswitch-codec-mp4v
    freeswitch-codec-opus
    freeswitch-codec-passthru-amr
    freeswitch-codec-passthru-amrwb
    freeswitch-codec-passthru-g723_1
    freeswitch-codec-passthru-g729
    freeswitch-codec-silk
    freeswitch-codec-siren
    freeswitch-codec-speex
    freeswitch-codec-theora
    freeswitch-config-vanilla
    freeswitch-endpoint-dingaling
    freeswitch-endpoint-portaudio
    freeswitch-endpoint-rtmp
    freeswitch-endpoint-skinny
    freeswitch-endpoint-skypopen
    freeswitch-event-erlang-event
    freeswitch-event-kazoo
    freeswitch-event-json-cdr
    freeswitch-event-multicast
    freeswitch-event-snmp
    freeswitch-format-local-stream
    freeswitch-format-mod-shout
    freeswitch-format-native-file
    freeswitch-format-portaudio-stream
    freeswitch-format-tone-stream
    freeswitch-freetdm
    freeswitch
    freeswitch-lang-en
    freeswitch-xml-curl
    freeswitch-custom-sounds
    freeswitch-custom-music
    freeswitch-sounds-en-us-callie-8000
    freeswitch-sounds-music-8000
    }.each do |pkg|
      yum_package "#{pkg}" do
        action :upgrade
        version "#{node[:freeswitch_version]}"
      end
    end

  script "change ownership of freeswitch dirs" do
    interpreter "bash"
    user "root"
    cwd "/usr/src"
    code <<-EOH
      chown -R freeswitch:daemon /opt/freeswitch
      chown -R freeswitch:daemon /etc/freeswitch
      chown -R freeswitch:daemon /usr/share/freeswitch
      chown -R freeswitch:daemon /var/log/freeswitch
    EOH
  end

  script "remove default sip_profile" do
    interpreter "bash"
    user "root"
    cwd "/etc/freeswitch/sip_profiles"
    code <<-EOH
        cd /etc/freeswitch/sip_profiles
        rm -f external.xml internal-ipv6.xml
        rm -Rf internal
        rm -Rf external
    EOH
    ignore_failure true
  end

  template "/etc/default/freeswitch" do
    source "freeswitch.erb"
    owner "root"
    group "root"
    mode 0644
  end

  template "/etc/init.d/freeswitch" do
    source "freeswitch-bluepill-init.erb"
    owner "root"
    group "root"
    mode 0755
  end
end

service "freeswitch" do
  reload_command "/opt/freeswitch/bin/fs_cli -x 'reloadxml' && /opt/freeswitch/bin/fs_cli -x 'reloadacl'"
  supports :status => true, :restart => true, :reload => true
  action [ :enable ]
end

directory "/opt/freeswitch/log" do
  action :create
  owner "freeswitch"
  group "daemon"
  mode "0755"
end

directory "/usr/share/freeswitch/http_cache" do
  action :create
  owner "freeswitch"
  group "daemon"
  mode "0755"
end

directory "/etc/freeswitch/" do
  not_if { ::FileTest.exists?("/etc/freeswitch/.git/config") }
  recursive true
  action :delete
end

git "/etc/freeswitch" do
  destination "/etc/freeswitch"
  repository "git://github.com/2600hz/whistle-fs.git"
  if node.chef_environment == "qa"
    reference "qa"
  else
    reference "master"
  end
  action :sync
end

template "/etc/freeswitch/autoload_configs/.erlang.cookie" do
  source "erlang.cookie.erb"
  owner "freeswitch"
  group "daemon"
  mode	"0600"
  notifies :reload, resources(:service => "freeswitch")
end

template "/etc/freeswitch/autoload_configs/erlang_event.conf.xml" do
  source "erlang_event.conf.xml.erb"
  owner "freeswitch"
  group "daemon"
  mode "0644"
end

template "/etc/freeswitch/autoload_configs/kazoo.conf.xml" do
  source "kazoo.conf.xml.erb"
  owner "freeswitch"
  group "daemon"
  mode "0644"
end

template "/etc/security/limits.d/freeswitch.limits.conf" do
  source "freeswitch.limits.conf.erb"
  owner  "root"
  group  "root"
  mode   "0644"
end

template "/etc/freeswitch/autoload_configs/acl.conf.xml" do
  source "#{node[:freeswitch][:acl_conf_file]}"
  owner "freeswitch"
  group "daemon"
  mode "0644"
  variables :opensips => opensips
end

template "/etc/bluepill/freeswitch.pill" do
  source "freeswitch.pill.erb"
end

template "/etc/bashrc" do
  source "bashrc.erb"
  mode "0644"
end

cookbook_file "/usr/local/bin/fetch_remote_audio.sh" do
  source "fetch_remote_audio.sh"
  mode "0755"
  owner "root"
  group "root"
end

script "change ownership of freeswitch dirs" do
    interpreter "bash"
    user "root"
    cwd "/usr/src"
    code <<-EOH
      chown -R freeswitch:daemon /opt/freeswitch
      chown -R freeswitch:daemon /etc/freeswitch
      chown -R freeswitch:daemon /var/log/freeswitch
    EOH
  end

bluepill_service "freeswitch" do
  action [:load]
end
