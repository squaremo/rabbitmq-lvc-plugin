APP_NAME=rabbitmq_lvc
DEPS=rabbitmq-server rabbitmq-erlang-client
WITH_BROKER_TEST_COMMANDS:=eunit:test(rabbit_lvc_test,[verbose])
