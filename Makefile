VAULT_SERVER := `docker ps | grep 0.0.0.0:8200 | cut -d' ' -f1`
VAULT_AGENT := `docker ps | grep vault | grep agent | cut -d' ' -f1`
HELM := `docker ps | grep helm | cut -d' ' -f1`
KUBECTL := `docker ps | grep kubectl | cut -d' ' -f1`
STEP := `docker ps | grep step-cli | cut -d' ' -f1`

vault:
	docker exec -it $(VAULT_SERVER) sh

agent:
	docker exec -it $(VAULT_AGENT) sh

helm:
	docker exec -it $(HELM) sh

kubectl:
	docker exec -it $(KUBECTL) sh

step:
	docker exec -it $(STEP) bash

certs:
	docker exec -it $(STEP) bash /vault/scripts/generate-certs.sh

install:
	docker exec -it $(HELM) sh /vault/scripts/install-vault-helm-chart.sh

uninstall:
	docker exec -it $(HELM) helm delete -n vault vault-injector
	docker exec -it $(KUBECTL) kubectl delete ns vault demo

secrets:
	docker exec -it $(VAULT_SERVER) sh /vault/scripts/vault-secrets.sh

policies:
	docker exec -it $(VAULT_SERVER) sh /vault/scripts/vault-policies.sh

authsetup:
	docker exec -it $(VAULT_SERVER) sh /vault/scripts/vault-auth.sh

vaultenv:
	docker exec -it $(KUBECTL) bash /vault/scripts/fetch-vault-env.sh

vaultproxy:
	docker exec -it $(KUBECTL) kubectl apply -f /vault/config/vault-proxy.yaml

dnsutils:
	docker exec -it $(KUBECTL) kubectl apply -f /vault/config/dnsutils.yaml

demo:
	docker exec -it $(KUBECTL) kubectl apply -f /vault/config/demo.yaml

build: up certs install secrets policies vaultenv vaultsvc authsetup demo

clean:
	sudo rm -rf data/certs/* data/file/* data/logs/* data/config/vault.env
	docker-compose down

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs
