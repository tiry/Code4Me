
# Goal

The overall is to become more efficient coding while avoiding sending all our code and data outside.

Naively, the problem can be broken down in 3 steps:

 1 - Train: /Fine tune a LLM on our code
 2 - Inferance: Run the resulting Model in the Cloud
 3 - Coding: Integrate LLM into IDE workflwo

# 1 - Fine tuning

Full toolink to fine tune existing LLMS : [axolotl](https://github.com/OpenAccess-AI-Collective/axolotl)

XXX TODO !!!

# 2 - Inference 

AWS SageMaker and GCP Vertex.AI provide similar services.

For the sake of understanding and having more control, I looked at SkyPilot.

## Sky Pilot 

SkyPilot ([skypilot](https://github.com/skypilot-org/skypilot/)) provide tooling to:

 - provision GPU on different Cloud Providers
    - including support for Spot instances
 - deploy Jobs on the provisioned nodes

Behind the scene, Skypilot use different framework to run the model or the training:

 - [VLLM](https://github.com/vllm-project/vllm)
 - [axolotl](https://github.com/OpenAccess-AI-Collective/axolotl)

Examples: https://github.com/skypilot-org/skypilot/tree/master/llm/codellama

## Install Sky

### Install MiniConda

see https://docs.anaconda.com/free/miniconda/

(I used `Miniconda3-latest-MacOSX-arm64.sh`)

### Install Sky

Create Conda Env

    conda create -y -n sky python=3.10
    conda activate sky

Install package

    pip install "skypilot-nightly[aws]"

### AWS Setup

Provided you are using aws-vault, you will need to generate the `credentias` file to sky to work

Here is the hack I used

    aws-vault export tiry-dev --format=ini > ~/.aws/credentials ; sed -i '' '1s/.*/[default]/' ~/.aws/credentials

see [aws_refresh.sh](scripts/aws_refresh.sh) for a ready to run script.

Once done, you should be able to run the following check:

    sky check

In the output you should see

    AWS: enabled   

(otherwise check that your ~/.aws/credentials is up to date)

### Configure Endpoint

The current endpoint is a mix of 3 sources:

 - [codellama/endpoint.yaml](https://github.com/skypilot-org/skypilot/blob/master/llm/codellama/endpoint.yaml)
 - [vllm/serve.yaml](https://github.com/skypilot-org/skypilot/blob/master/llm/vllm/serve.yaml)
 - this [blog post](https://blog.skypilot.co/serving-llm-24x-faster-on-the-cloud-with-vllm-and-skypilot/) 

Resulting file is [endpoint.yaml](endpoint.yaml)

Important adjustments:

**GPU**

I needed to use `A10G` because I had troubles being able to provision A100-80GB or V100-32GB 

You can check available GPU using

    sky show-gpus

**max-model-len**

I had to add `--max-model-len 10000` to the vllm command line to avoid the following error:

    (task, pid=31428) ValueError: The model's max seq len (16384) is larger than the maximum number of tokens that can be stored in KV cache (11040). Try increasing `gpu_memory_utilization` or decreasing `max_model_len` when initializing the engine.

**model size**

Downgrade the model to `codellama/CodeLlama-7b-Instruct-hf`

See : https://huggingface.co/codellama

### Deploy Model

    sky launch -c my-coding-assistant endpoint.yaml 

This take ~15 minutes

### Run Model 

NB: the Launch seems to also run the `run` part so ...

Once the VM is deployed, we can start the service:

    sky exec my-coding-assistant endpoint.yaml 

Then we need to get the IP:

    IP=$(sky status --ip my-coding-assistant)

    sky status --ip my-coding-assistant

### Testing the model

vllm expose the OpenAI API

So you can do something like

    curl http://52.32.243.169:8000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{
         "model": "codellama/CodeLlama-7b-Instruct-hf",
         "messages": [{"role": "user", "content": "Say this is a test!"}],
         "temperature": 0.7
       }'

### Shuting down

Stop Service

    sky stop my-coding-assistant

Kill VM

    sky down my-coding-assistant


# 3 - Integrate with IDE

## Plugin choice

I tested with [continue](https://continue.dev/) that has a few interesting qualities:

 - it works for [VSCode](https://marketplace.visualstudio.com/items?itemName=Continue.continue) and [IntelliJ](https://plugins.jetbrains.com/plugin/22707-continue)
 - it is opensource [continuedev/continue](https://github.com/continuedev/continue)


## Configuration

Inside teh `config.json` used by Continue, add the new service

    {
      "title": "Codellama 7b Sky",
      "provider": "openai",
      "model": "codellama/CodeLlama-7b-Instruct-hf",
      "apiBase": "http://52.32.243.169:8000/v1"
    }

