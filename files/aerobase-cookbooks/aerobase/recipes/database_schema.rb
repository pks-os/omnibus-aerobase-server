#
# Copyright:: Copyright (c) 2018, Aerobase Inc
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

install_dir = node['package']['install-dir']

account_helper = AccountHelper.new(node)
aerobase_user = account_helper.aerobase_user
aerobase_group = account_helper.aerobase_group
os_helper = OsHelper.new(node)

database_name = node['unifiedpush']['unifiedpush-server']['db_database']
database_username = node['unifiedpush']['unifiedpush-server']['db_username']
database_adapter = node['unifiedpush']['unifiedpush-server']['db_adapter']
mssql_instance = node['unifiedpush']['mssql']['instance']
mssql_login = node['unifiedpush']['mssql']['logon']

unifiedpush_vars = node['unifiedpush']['unifiedpush-server'].to_hash

if os_helper.is_windows?
  tmp_dir = "Temp"
  command = "init-unifiedpush-db.bat /#{install_dir}/#{tmp_dir} > #{install_dir}/#{tmp_dir}/initdb.log"
else
  tmp_dir = "tmp"
  command = "./init-unifiedpush-db.sh --config-path=#{install_dir}/#{tmp_dir}"
end 

jdbc_type = database_adapter
jdbc_instance = ""
jdbc_properties = ""
jdbc_hbm_dialect = "org.hibernate.dialect.PostgreSQL95Dialect"
jdbc_database = "/#{database_name}"

if database_adapter == "mssql"
  jdbc_type = "sqlserver"
  jdbc_instance = "\\#{mssql_instance}"
  jdbc_properties = mssql_login ? ";user=#{database_username};password=#{database_username};" : ";integratedSecurity=true;"
  jdbc_hbm_dialect = "org.hibernate.dialect.SQLServerDialect"
  jdbc_database = ";databaseName=#{database_name}"
end

directory "#{install_dir}/#{tmp_dir}" do
  owner aerobase_user
  group aerobase_group
  mode "0755"
  recursive true
  action :create
end

template "#{install_dir}/#{tmp_dir}/db.properties" do
  source "unifiedpush-server-db-properties.erb"
  owner aerobase_user
  group aerobase_group
  mode "0644"
  variables(unifiedpush_vars.merge({
      :jdbc_type => jdbc_type,
	  :jdbc_instance => jdbc_instance, 
	  :jdbc_database => jdbc_database,
	  :jdbc_properties => jdbc_properties
    }
  ))
end

template "#{install_dir}/#{tmp_dir}/hibernate.properties" do
  source "unifiedpush-server-hibernate.properties.erb"
  owner aerobase_user
  group aerobase_group
  mode "0644"
  variables(unifiedpush_vars.merge({
      :jdbc_hbm_dialect => jdbc_hbm_dialect
    }
  ))
end

execute "initialize unifiedpush-server database" do
  cwd "#{install_dir}/embedded/apps/unifiedpush-server/initdb/bin"
  command "#{command}"
end