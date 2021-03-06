default_conf_file = "#{node[:nginx_dir]}/sites-available/000-default"
enabled_conf_file = "#{node[:nginx_dir]}/sites-enabled/000-default"

if node[:nginx_default_site]
  rails_log_dir = ::File.join(node[:primero][:log_dir], 'rails')

  ssl_dir = ::File.join(node[:nginx_dir], 'ssl')

  template default_conf_file do
    source "nginx_default.erb"
    owner 'root'
    group 'root'
    mode '0644'
    variables({
      :http_port => node[:primero][:http_port],
      :https_port => node[:primero][:https_port],
      :log_dir => rails_log_dir,
      :ssl_cert_path => ::File.join(ssl_dir, 'primero.crt'),
      :ssl_key_path => ::File.join(ssl_dir, 'primero.key')
    })
    notifies :restart, 'service[nginx]'
  end

  link enabled_conf_file do
    to default_conf_file
  end
else

  link enabled_conf_file do
    action :delete
  end

end