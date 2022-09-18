run:
	docker build -t gmd `pwd`
	docker run --add-host host.docker.internal:host-gateway --name gt -v "/media/thetechrobo/2tb/gmddata:/finished" --rm gmd test
runkf:
	docker build -t gmd `pwd`
	docker run --add-host host.docker.internal:host-gateway --name gt -v "/media/thetechrobo/2tb/gmddata:/finished" --rm gmd test --keep-data
