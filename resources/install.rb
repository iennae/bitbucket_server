#
# Cookbook:: bitbucket_server
# Resource:: install
#
resource_name :bitbucket_install

property :product, String, default: 'bitbucket'
property :version, String, default: '5.0.1'
property :bitbucket_user, String, default: 'atlbitbucket'
property :bitbucket_group, String, default: 'atlbitbucket'
property :home_path, String, default: '/var/atlassian/application-data/bitbucket'
property :install_path, String, default: '/opt/atlassian'
property :checksum, String, default: lazy {
                                       case version
                                       when '5.0.1'
                                         '677528dffb770fab9ac24a2056ef7be0fc41e45d23fc2b1d62f04648bfa07fad'
                                       when '5.0.0'
                                         'a1505e06dc126279c710ce6c289fc41b078bab5de0beff44fc27bd17339ebdf9'
                                       end
                                     }
property :url_base, String, default: 'http://www.atlassian.com/software/stash/downloads/binary/atlassian-bitbucket'
property :jre_home, String

action :install do
  validate_version

  directory new_resource.home_path do
    owner 'root'
    group 'root'
    mode 00755
    action :create
    recursive true
    not_if { ::Dir.exist?(new_resource.home_path) }
  end

  group new_resource.bitbucket_group do
    action :create
    append true
  end

  user new_resource.bitbucket_user do
    gid new_resource.bitbucket_group
    comment 'Bitbucket Service Account'
    home new_resource.home_path
    shell '/bin/bash'
    manage_home true
    system true
    action :create
  end

  # changing ownership after user creation
  directory new_resource.home_path do
    owner new_resource.bitbucket_user
    group new_resource.bitbucket_group
    mode 00755
    action :create
    recursive true
  end

  directory new_resource.install_path do
    owner new_resource.bitbucket_user
    group new_resource.bitbucket_group
    mode 00755
    action :create
    recursive true
  end

  ark new_resource.product do
    url pkg_url
    prefix_root new_resource.install_path
    prefix_home new_resource.install_path
    checksum new_resource.checksum
    version new_resource.version
    owner new_resource.bitbucket_user
    group new_resource.bitbucket_group
    notifies :restart, "service[#{new_resource.product}]", :delayed
  end

  template "#{new_resource.install_path}/bitbucket/bin/set-bitbucket-home.sh" do
    source 'set-bitbucket-home.sh.erb'
    owner new_resource.bitbucket_user
    group new_resource.bitbucket_group
    mode 00755
    action :create
    variables(
      home_path: new_resource.home_path
    )
    cookbook 'bitbucket_server'
    notifies :restart, "service[#{new_resource.product}]", :delayed
  end

  template "#{new_resource.install_path}/bitbucket/bin/set-jre-home.sh" do
    source 'set-jre-home.sh.erb'
    owner new_resource.bitbucket_user
    group new_resource.bitbucket_group
    mode 00755
    action :create
    variables(
      jre_home: new_resource.jre_home
    )
    cookbook 'bitbucket_server'
    notifies :restart, "service[#{new_resource.product}]", :delayed
  end

  service new_resource.product do
    supports restart: true, start: true, stop: true, status: true
    action [:nothing]
    only_if "service #{new_resource.product} status"
  end
end

action_class.class_eval do
  # ensure version in semver format MAJOR.MINOR.PATCH
  def validate_version
    return if new_resource.version =~ /\d+.\d+.\d+/
    Chef::Log.fatal("The version must be in MAJOR.MINOR.PATCH format. Passed value: #{new_resource.version}")
    raise
  end

  def pkg_url
    "#{new_resource.url_base}-#{new_resource.version}.tar.gz"
  end
end
