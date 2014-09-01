#
# Cookbook Name:: jmxtrans
# Recipe:: default
#
# Copyright 2012, Bryan W. Berry
# Copyright 2013, Brian Flad
#
# Apache 2.0 license
#

if node['jmxtrans']['url'].end_with?('.deb')
  tmp_file = '/tmp' << node['jmxtrans']['url'].match('/[^/]*$').to_s
  remote_file tmp_file do
    source node['jmxtrans']['url']
    mode 0644
    checksum node['jmxtrans']['checksum']
  end

  dpkg_package 'jmxtrans' do
    source tmp_file
    action :install
  end

else

  include_recipe 'ark'

  ark 'jmxtrans' do
    url node['jmxtrans']['url']
    checksum node['jmxtrans']['checksum']
    version 'latest'
    prefix_root node['jmxtrans']['install_prefix']
    prefix_home node['jmxtrans']['install_prefix']
    owner node['jmxtrans']['user']
    group node['jmxtrans']['user']
  end
end

user node['jmxtrans']['user']

servers = node.default['jmxtrans']['servers']
servers.each do |server|
  queries = []
  queries << node['jmxtrans']['default_queries']['jvm']
  queries << node['jmxtrans]['default_queries'][server['type']]
  queries.compact.flatten!
  server['queries'] << queries
end

file "#{node['jmxtrans']['home']}/jmxtrans.sh" do
  owner node['jmxtrans']['user']
  group node['jmxtrans']['user']
  mode 00755
end

if platform_family?('debian')
  template '/etc/init.d/jmxtrans' do
    source 'jmxtrans.init.deb.erb'
    owner 'root'
    group 'root'
    mode '0755'
    variables(:name => 'jmxtrans')
    notifies :restart, 'service[jmxtrans]'
  end
elsif platform_family?('rhel')
  template '/etc/init.d/jmxtrans' do
    source 'jmxtrans.init.el.erb'
    owner 'root'
    group 'root'
    mode '0755'
    variables(:name => 'jmxtrans')
    notifies :restart, 'service[jmxtrans]'
  end
else
  fail "Unknown platform family in jmxtrans -- don't have an init template!"
end

template '/etc/default/jmxtrans' do
  source 'jmxtrans_default.erb'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[jmxtrans]'
end

directory node['jmxtrans']['log_dir'] do
  owner node['jmxtrans']['user']
  group node['jmxtrans']['user']
  mode '0755'
end

directory "#{node['jmxtrans']['home']}/json" do
  owner node['jmxtrans']['user']
  group node['jmxtrans']['user']
  mode '0755'
end

template "#{node['jmxtrans']['home']}/json/set1.json" do
  source 'set1.json.erb'
  owner node['jmxtrans']['user']
  group node['jmxtrans']['user']
  mode '0755'
  notifies :restart, 'service[jmxtrans]'
  variables(
            :servers => servers,
            :graphite_host => node['jmxtrans']['graphite']['host'],
            :graphite_port => node['jmxtrans']['graphite']['port'],
            :root_prefix => node['jmxtrans']['root_prefix']
            )
end

package 'gzip'

cron 'compress and remove logs rotated by log4j' do
  minute '0'
  hour '0'
  command "find #{node['jmxtrans']['log_dir']}/ -name '*.gz' -mtime +30 -exec rm -f '{}' \\; ; \
  find #{node['jmxtrans']['log_dir']} ! -name '*.gz' -mtime +2 -exec gzip '{}' \\;"
end

execute 'set correct jps alternative' do
  command 'update-alternatives jps --auto jps'
  creates '/usr/bin/jps'
end

service 'jmxtrans' do
  supports :restart => true, :status => true, :reload => true
  action [:enable, :start]
end
