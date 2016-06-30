#
# Cookbook Name:: jmxtrans
# Recipe:: default
#
# Copyright 2012, Bryan W. Berry
# Copyright 2013, Brian Flad
#
# Apache 2.0 license
#

poise_service_user node['jmxtrans']['user'] do
  home node['jmxtrans']['home']
  group node['jmxtrans']['user']
end

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


servers = node['jmxtrans']['servers']
node.default[:jmxtrans][:servers_ex] = servers.map do |server|
  queries = []
  queries << node['jmxtrans']['default_queries']['jvm']
  queries << node['jmxtrans']['default_queries'][server['type']]
  srv = server.dup
  srv['queries'] = queries.compact.flatten
  srv['alias'] ||= node['jmxtrans']['server_alias']
  srv
end



file "#{node['jmxtrans']['home']}/jmxtrans.sh" do
  owner node['jmxtrans']['user']
  group node['jmxtrans']['user']
  mode 00755
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
  notifies :restart, 'poise_service[jmxtrans]'
  variables(
            :servers => node[:jmxtrans][:servers_ex],
            :graphite_host => node['jmxtrans']['graphite']['host'],
            :graphite_port => node['jmxtrans']['graphite']['port'],
            :root_prefix => node['jmxtrans']['root_prefix'],
            :key_suffix => node['jmxtrans']['key_suffix']
            )
end

package 'gzip'

cron 'compress and remove logs rotated by log4j' do
  minute '0'
  hour '0'
  command "find #{node['jmxtrans']['log_dir']}/ -name '*.gz' -mtime +30 -exec rm -f '{}' \\; ; \
  find #{node['jmxtrans']['log_dir']} ! -name '*.gz' -mtime +2 -exec gzip '{}' \\;"
end

java_command = ['/usr/bin/java',
                '-Xms${HEAP_SIZE}M',
                '-Xmx${HEAP_SIZE}M',
                '-XX:+UseConcMarkSweepGC',
                '-XX:NewRatio=${NEW_RATIO}',
                '-XX:NewSize=${NEW_SIZE}m',
                '-XX:MaxNewSize=${NEW_SIZE}m',
                '-XX:MaxTenuringThreshold=16',
                '-XX:GCTimeRatio=9',
                '-XX:PermSize=${PERM_SIZE}m',
                '-XX:MaxPermSize=${MAX_PERM_SIZE}m',
                '-XX:+UseTLAB',
                '-XX:CMSInitiatingOccupancyFraction=${IO_FRACTION}',
                '-XX:+CMSIncrementalMode',
                '-XX:+CMSIncrementalPacing',
                '-XX:ParallelGCThreads=${CPU_CORES}',
                '-Dsun.rmi.dgc.server.gcInterval=28800000',
                '-Dsun.rmi.dgc.client.gcInterval=28800000',
                '-Djava.awt.headless=true',
                '-Djava.net.preferIPv4Stack=true',
                '-Djmxtrans.log.level=${LOG_LEVEL}',
                '-Djmxtrans.log.dir=${LOG_DIR}',
                '-jar',
                '$JAR_FILE',
                '-e',
                '-j ${JSON_DIR}',
                '-s ${SECONDS_BETWEEN_RUNS}',
                '-c ${CONTINUE_ON_ERRORS}',
                ].join(' ')

poise_service 'jmxtrans' do
  environment(
    :JAR_FILE => "#{node['jmxtrans']['home']}/jmxtrans-all.jar",
    :LOG_DIR => node['jmxtrans']['log_dir'],
    :CONTINUE_ON_ERRORS => 'false',
    :SECONDS_BETWEEN_RUNS => node['jmxtrans']['run_interval'],
    :JSON_DIR => "#{node['jmxtrans']['home']}/json",
    :HEAP_SIZE => node['jmxtrans']['heap_size'],
    :NEW_SIZE => 64,
    :CPU_CORES => node['cpu']['total'],
    :NEW_RATIO => 8,
    :LOG_LEVEL => node['jmxtrans']['log_level'],
    :PERM_SIZE => 384,
    :MAX_PERM_SIZE => 384,
    :IO_FRACTION => 85
  )
  command java_command
  directory node['jmxtrans']['home']
  action [:enable, :start]
end
