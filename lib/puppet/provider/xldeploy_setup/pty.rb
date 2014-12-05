require 'uri'
require 'etc'
require "digest/md5"
require 'pty'
require 'expect'

Puppet::Type.type(:xldeploy_setup).provide(:pty)  do

  commands  :chown    => '/bin/chown',
            :chgrp    => '/bin/chgrp'

  def create
    command = "#{resource[:homedir]}/bin/server.sh -setup"

    PTY.spawn(command) do |input, output, pid|

      line_array = []
      output.sync = true
      input.each { |line|
        Puppet.debug line

        # we do not want the password encryption key to be secured by a password because we can't work with that in puppet
        if line_array[-1] =~ /The password encryption key is optionally secured by a password./
          output.puts("\n") if line =~ /Please enter the password you wish to use/
        end

        if line_array[-2] =~ /The password encryption key is optionally secured by a password./
          output.puts("\n") if line =~ /New password/
        end

        if line_array[-3] =~ /The password encryption key is optionally secured by a password./
          output.puts("\n") if line =~ /Re-type password/
        end


        if line =~ /Options are yes or no./
          output.puts('no') if line_array[-1] =~ /Default values are used for all properties. To make changes to the default properties, please answer no./
          output.puts(yes_or_no(resource[:ssl])) if line_array[-1] =~ /Would you like to enable SSL/
          output.puts('yes') if line_array[-1] =~ /Self-signed certificates do not work correctly with some versions of the Flash Player and some browsers!/
          output.puts('yes') if line_array[-1] =~ /Do you want to initialize the JCR repository?/
          output.puts('yes') if line_array[-1] =~ /Do you want to generate a new password encryption key?/
        end

        output.puts('yes') if line =~ /Are you sure you want to continue (yes or no)?/
        output.puts('no') if line =~ /selecting no will create an empty configuration/
        output.puts(resource[:admin_password]) if line =~ /Please enter the admin password you wish to use for XL Deploy Server/
        output.puts(resource[:admin_password]) if line =~ /New password/
        output.puts(resource[:http_bind_address]) if line =~ /What http bind address would you like the server to listen on/
        output.puts(resource[:http_port]) if line =~ /What http port number would you like the server to listen on/
        output.puts(resource[:http_content_root]) if line =~ /Enter the web context root where XL Deploy Server will run/
        output.puts('3') if line =~ /Enter the minimum number of threads the HTTP server should use/
        output.puts('24') if line =~ /Enter the maximum number of threads the HTTP server should use/
        output.puts('repository') if line =~ /Where would you like to store the JCR repository/
        output.puts('packages') if line =~ /Where would you like XL Deploy Server to import packages from/
        output.puts('yes') if line =~ /Application import location is/
        break if line =~ /Finished setup/

        line_array << line

      }

      chown('-R',"#{resource[:owner]}:#{resource[:group]}", "#{resource[:homedir]}" )


    end
  end

  def exists?
    return false
  end

  def destroy
    rm('-rf', resource[:destinationdir] )
  end


  private


  def yes_or_no(x)
    return 'yes' if x.class == TrueClass
    return 'no'
  end


end
