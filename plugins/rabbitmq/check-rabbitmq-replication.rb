#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'socket'
require 'carrot-top'

class CheckRabbitMQReplication < Sensu::Plugin::Check::CLI
  option :host,
         description: 'RabbitMQ management API host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'RabbitMQ management API port',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 15_672

  option :ssl,
         description: 'Enable SSL for connection to the API',
         long: '--ssl',
         boolean: true,
         default: false

  option :user,
         description: 'RabbitMQ management API user',
         long: '--user USER',
         default: 'guest'

  option :password,
         description: 'RabbitMQ management API password',
         long: '--password PASSWORD',
         default: 'guest'

  def acquire_rabbitmq_info
    begin
      rabbitmq_info = CarrotTop.new(
        host: config[:host],
        port: config[:port],
        user: config[:user],
        password: config[:password],
        ssl: config[:ssl]
      )
    rescue
      warning 'could not get rabbitmq info'
    end
    rabbitmq_info
  end

  def run
    @crit = []

    rabbitmq = acquire_rabbitmq_info
    queues = rabbitmq.queues

    queues.each do |queue|
      if queue['policy'] == 'ha-all'
        unless queue['slave_nodes'].sort == queue['synchronised_slave_nodes'].sort
          @crit << "#{queue['name']} has #{(queue['slave_nodes'] - queue['synchronised_slave_nodes']).length} out of sync slave(s)"
        end
      end
    end

    if @crit.empty?
      ok "all replicated queues are in sync"
    else
      critical @crit.join(' & ')
    end
  end

end
