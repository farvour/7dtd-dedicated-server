import * as k8s from "@pulumi/kubernetes"
import * as kx from "@pulumi/kubernetesx"
import * as pulumi from "@pulumi/pulumi"

import { readFileSync } from "fs"

const config = new pulumi.Config()

// Configuration.
const image = `${config.require("image")}:${config.require("imageTag")}`

// Namespace
const ns = new k8s.core.v1.Namespace("7dtd-dedicated-server", {
  metadata: { name: "7dtd-dedicated-server" },
})

// ConfigMap.
const configMaps = new Map<string, k8s.core.v1.ConfigMap>()
configMaps.set("serverconfig", new k8s.core.v1.ConfigMap("7dtd-dedicated-server-serverconfig", {
  metadata: {
    name: "7dtd-dedicated-server-serverconfig",
    namespace: ns.id,
  },
  data: {
    "serverconfig.xml": readFileSync("../../config/serverconfig.xml", "utf8"),
  },
}))

// StatefulSet.
interface StatefulSetLabelData {
  labels: undefined
}
const statefulSetConfig = config.requireObject<StatefulSetLabelData>("statefulSet")
const statefulSets = new Map<string, k8s.apps.v1.StatefulSet>()
statefulSets.set("dedicated-server", new k8s.apps.v1.StatefulSet("dedicated-server", {
  metadata: {
    name: "dedicated-server",
    namespace: ns.id,
  },
  spec: {
    podManagementPolicy: "OrderedReady",
    serviceName: "7dtd-dedicated-server",
    selector: { matchLabels: statefulSetConfig.labels },
    replicas: 1,
    template: {
      metadata: { labels: statefulSetConfig.labels },
      spec: {
        containers: [
          {
            name: "dedicated-server",
            command: [],
            image: image,
            ports: [
              { name: "game-tcp-0", containerPort: 26900, protocol: "TCP" },
              { name: "game-tcp-1", containerPort: 26901, protocol: "TCP" },
              { name: "game-tcp-2", containerPort: 26902, protocol: "TCP" },
              { name: "game-tcp-3", containerPort: 26903, protocol: "TCP" },
              { name: "game-tcp-4", containerPort: 26904, protocol: "TCP" },
              { name: "game-tcp-5", containerPort: 26905, protocol: "TCP" },
              { name: "game-udp-0", containerPort: 26900, protocol: "UDP" },
              { name: "game-udp-1", containerPort: 26901, protocol: "UDP" },
              { name: "game-udp-2", containerPort: 26902, protocol: "UDP" },
              { name: "game-udp-3", containerPort: 26903, protocol: "UDP" },
              { name: "game-udp-4", containerPort: 26904, protocol: "UDP" },
              { name: "game-udp-5", containerPort: 26905, protocol: "UDP" },
            ],
            readinessProbe: {
              failureThreshold: 5, successThreshold: 2,
              timeoutSeconds: 5, initialDelaySeconds: 200, periodSeconds: 10,
              tcpSocket: { port: 26900 },
            },
            terminationMessagePolicy: "FallbackToLogsOnError",
            volumeMounts: [
              { name: "data", mountPath: "/app/7dtd/data" },
              { name: "serverconfig", mountPath: "/app/7dtd/dedicated-server/serverconfig1" },
            ],
          }],
        volumes: [
          { name: "serverconfig", configMap: { name: configMaps.get("serverconfig")?.metadata.name } },
        ],
      }
    },
    volumeClaimTemplates: [{
      metadata: {
        name: "data",
      },
      spec: {
        accessModes: ["ReadWriteOnce"],
        resources: {
          requests: {
            storage: "9Gi",
          },
        }
      },
    }],
  }
}))

// Service.
const svc = new k8s.core.v1.Service("dedicated-server", {
  metadata: { name: "dedicated-server", namespace: ns.id },
  spec: {
    ports: [
      { name: "game-tcp-0", nodePort: 26900, port: 26900, targetPort: "game-tcp-0", protocol: "TCP", },
      { name: "game-tcp-1", nodePort: 26901, port: 26901, targetPort: "game-tcp-1", protocol: "TCP", },
      { name: "game-tcp-2", nodePort: 26902, port: 26902, targetPort: "game-tcp-2", protocol: "TCP", },
      { name: "game-tcp-3", nodePort: 26903, port: 26903, targetPort: "game-tcp-3", protocol: "TCP", },
      { name: "game-tcp-4", nodePort: 26904, port: 26904, targetPort: "game-tcp-4", protocol: "TCP", },
      { name: "game-tcp-5", nodePort: 26905, port: 26905, targetPort: "game-tcp-5", protocol: "TCP", },
      { name: "game-udp-0", nodePort: 26900, port: 26900, targetPort: "game-udp-0", protocol: "UDP", },
      { name: "game-udp-1", nodePort: 26901, port: 26901, targetPort: "game-udp-1", protocol: "UDP", },
      { name: "game-udp-2", nodePort: 26902, port: 26902, targetPort: "game-udp-2", protocol: "UDP", },
      { name: "game-udp-3", nodePort: 26903, port: 26903, targetPort: "game-udp-3", protocol: "UDP", },
      { name: "game-udp-4", nodePort: 26904, port: 26904, targetPort: "game-udp-4", protocol: "UDP", },
      { name: "game-udp-5", nodePort: 26905, port: 26905, targetPort: "game-udp-5", protocol: "UDP", },
    ],
    selector: statefulSetConfig.labels,
    type: "NodePort",
  },
})
