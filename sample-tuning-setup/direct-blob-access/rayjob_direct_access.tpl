apiVersion: ray.io/v1
kind: RayJob
metadata:
  name: rayjob-tune-gpt2
  namespace: kuberay
spec:
  shutdownAfterJobFinishes: false
  entrypoint: @ENTRYPOINT@
  runtimeEnvYAML: |
    working_dir: "https://github.com/mittachaitu/aks-ray-sample/archive/sai/wi.zip"
  # rayClusterSpec specifies the RayCluster instance to be created by the RayJob controller.
  rayClusterSpec:
    # Uncomment the next line to experiment with autoscaling.
    # enableInTreeAutoscaling: true
    # The version of Ray you are using. Make sure all Ray containers are running this version of Ray.
    rayVersion: '2.54.1'
    headGroupSpec:
      # Kubernetes Service Type, valid values are 'ClusterIP', 'NodePort' and 'LoadBalancer'
      serviceType: ClusterIP
      rayStartParams:
        dashboard-host: '0.0.0.0'
        block: 'true'
      template:
        metadata:
          labels:
            azure.workload.identity/use: "true"
        spec:
          serviceAccountName: @SERVICE_ACCOUNT_NAME@
          containers:
          # The Ray head container
          - name: ray-head
            image: docker.io/mittachaitu/rayworker:pywadl
            imagePullPolicy: IfNotPresent
            # Optimal resource allocation will depend on your Kubernetes infrastructure and might
            # require some experimentation.
            # Setting requests=limits is recommended with Ray. K8s limits are used for Ray-internal
            # resource accounting. K8s requests are not used by Ray.
            resources:
              limits:
                cpu: "14"
                memory: "54Gi"
              requests:
                cpu: "14"
                memory: "54Gi"
            env:
            - name: RAY_OBJECT_STORE_MEMORY
              value: "16G"
            lifecycle:
              preStop:
                exec:
                  command: ["/bin/sh","-c","ray stop"]
    workerGroupSpecs:
    - replicas: @NUM_WORKERS@
      minReplicas: @NUM_WORKERS@
      maxReplicas: @NUM_WORKERS@
      # To experiment with autoscaling,
      # set replicas and minReplicas to 0.
      # replicas: 0
      # minReplicas: 0
      groupName: large-group
      # the following params are used to complete the ray start: ray start --block
      rayStartParams:
        block: 'true'
      template:
        metadata:
          labels:
            azure.workload.identity/use: "true"
        spec:
          serviceAccountName: @SERVICE_ACCOUNT_NAME@
          containers:
          - name: machine-learning # must consist of lower case alphanumeric characters or '-', and must start and end with an alphanumeric character (e.g. 'my-name',  or '123-abc')
            image: docker.io/mittachaitu/rayworker:pywadl
            imagePullPolicy: IfNotPresent
            # Optimal resource allocation will depend on your Kubernetes infrastructure and might
            # require some experimentation.
            # Setting requests=limits is recommended with Ray. K8s limits are used for Ray-internal
            # resource accounting. K8s requests are not used by Ray.
            resources:
              limits:
                # Slightly less than 16 to accomodate placement on 16 vCPU virtual machine.
                cpu: "14"
                memory: "54Gi"
                # The node that hosts this pod should have at least 1000Gi disk space,
                # for data set storage.
              requests:
                cpu: "14"
                memory: "54Gi"
            env:
            - name: RAY_OBJECT_STORE_MEMORY
              value: "16G"
            lifecycle:
              preStop:
                exec:
                  command: ["/bin/sh","-c","ray stop"]
          initContainers:
          # the env var $RAY_IP is set by the operator, with the value of the head service name
          - name: init-myservice
            image: busybox:1.28
            command: ['sh', '-c', "until nslookup $RAY_IP.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local; do echo waiting for myservice; sleep 2; done"]
