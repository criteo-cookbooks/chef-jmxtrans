name 'jmxtrans'
maintainer 'Brian Flad'
maintainer_email 'bflad417@gmail.com'
license 'Apache 2.0'
description 'Installs/Configures jmxtrans'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.6.0'

%w(ark).each do |cb|
  depends cb
end

depends 'poise-service'

%w(centos redhat ubuntu).each do |os|
  supports os
end
