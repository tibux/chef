#
# Copyright:: Copyright (c) 2013-2015 Olivier Biesmans, Paris, FRANCE
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

require 'chef/mixin/shell_out'
require 'chef/provider/service'
require 'chef/mixin/command'

class Chef
  class Provider
    class Service
      class Slackware < Chef::Provider::Service::Init

        provides :service, os: [ "slackware" ]

        include Chef::Mixin::ShellOut

        def load_current_resource
          @current_resource = Chef::Resource::Service.new(@new_resource.name)
          @current_resource.service_name(@new_resource.service_name)
          @rcd_script_found = true
          @enabled_state_found = false
          if ::File.exists?("/etc/rc.d/rc.#{current_resource.service_name}")
            @rcd_script = "/etc/rc.d/rc.#{current_resource.service_name}"
          else
            @rcd_script_found = false 
            return
          end
          Chef::Log.debug("#{@current_resource} found at #{@rcd_script}")
          determine_current_status! # sets @current_resource.running 
          if @rcd_script_found
            @current_resource.enabled ::File.executable?(@rcd_script)
            @enabled_state_found = true
          end
          unless @current_resource.enabled
            Chef::Log.debug("#{@new_resource.name} enable/disable state unknown")
            @current_resource.enabled false
          end

          @current_resource
        end

        def define_resource_requirements
          shared_resource_requirements
          requirements.assert(:start, :enable, :reload, :restart) do |a|
            a.assertion { @rcd_script_found } 
            a.failure_message Chef::Exceptions::Service, "#{@new_resource}: unable to locate the rc.d script"
          end

          requirements.assert(:all_actions) do |a| 
            a.assertion { @enabled_state_found }  
            a.whyrun "Unable to determine enabled/disabled state, assuming this will be correct for an actual run.  Assuming disabled." 
          end
        end

        def start_service
          if @new_resource.start_command
            super
          else
            shell_out!("/bin/sh #{@rcd_script} start")
          end
        end

        def stop_service
          if @new_resource.stop_command
            super
          else
            shell_out!("/bin/sh #{@rcd_script} stop")
          end
        end

        def restart_service
          if @new_resource.restart_command

            super
          elsif @new_resource.supports[:restart]
            shell_out!("/bin/sh #{@rcd_script} restart")
          else
            stop_service
            sleep 1
            start_service
          end
        end

        def enable_service()
          shell_out!("chmod +x #{@rcd_script}")
        end

        def disable_service()
          shell_out!("chmod -x #{@rcd_script}")
        end

      end
    end
  end
end

