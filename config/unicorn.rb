# See http://unicorn.bogomips.org/Unicorn/Configurator.html for complete documentation
#
# This file should go in the config directory of your Rails app e.g. config/unicorn.rb

app_dir = "/www/redmine.dontpanic.com.ua/current"
worker_processes 8
working_directory app_dir

# Load app into the master before forking workers for super-fast
# worker spawn times
preload_app true

# nuke workers after 60 seconds (the default)
timeout 60

# listen on a Unix domain socket and/or a TCP port,

#listen 8080 # listen to port 8080 on all TCP interfaces
#listen "127.0.0.1:8080"  # listen to port 8080 on the loopback interface
listen "/tmp/redmine.dontpanic.com.ua.unicorn.socket", :backlog => 2048

# feel free to point this anywhere accessible on the filesystem
user 'www-data'

#pid "/tmp/yes.dontpanic.com.ua.unicorn.pid"
pid "#{app_dir}/tmp/pids/unicorn.pid"
stderr_path "#{app_dir}/log/unicorn.stderr.log"
stdout_path "#{app_dir}/log/unicorn.stdout.log"

# http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end


before_fork do |server, worker|
  # the following is highly recomended for Rails + "preload_app true"
  # as there's no need for the master process to hold a connection
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!

  ##
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.

  old_pid = "#{server.config[:pid]}.oldbin"

  if File.exists?(old_pid) && server.pid != old_pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|
  # Unicorn master loads the app then forks off workers - because of the way
  # Unix forking works, we need to make sure we aren't using any of the parent's
  # sockets, e.g. db connection

  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
  # Redis and Memcached would go here but their connections are established
  # on demand, so the master never opens a socket
end
