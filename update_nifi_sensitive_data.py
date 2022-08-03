import nipyapi, yaml, sys

with open('/Users/jaekim/.twitter-keys.yaml', 'r') as file:
    keys = yaml.load(file, Loader=yaml.FullLoader)

ip = sys.argv[1]
host = f'http://{ip}:8080/nifi-api'
print(host)
nipyapi.config.nifi_config.host = host
# nipyapi.config.registry_config.host = 'http://52.90.87.231:8080/nifi-registry-api'

group_id = nipyapi.canvas.get_root_pg_id()
template_id = nipyapi.templates.get_template('twitter').template.id
nipyapi.templates.deploy_template(group_id, template_id)


processor = nipyapi.canvas.get_processor('GetTwitter')
props = processor.component.config.properties
props["Consumer Key"] = keys['keys']['consumer_key']
props["Consumer Secret"] = keys['keys']['consumer_secret']
props["Access Token"] = keys['keys']['access_key']
props["Access Token Secret"] = keys['keys']['access_token_secret']

config = processor.component.config
config.properties = props

nipyapi.canvas.update_processor(processor, config)
controller = nipyapi.canvas.get_controller('DBCPConnectionPool')
controller_component_id = controller.component.id
controller_revision = controller.revision
nipyapi.canvas.update_controller(controller=nipyapi.nifi.ControllerServiceEntity(revision=controller_revision, id=controller_component_id), update=nipyapi.nifi.ControllerServiceDTO(properties={"Password":"debezium"}))
revised_controller = nipyapi.canvas.get_controller('DBCPConnectionPool')
nipyapi.canvas.schedule_controller(revised_controller,True)