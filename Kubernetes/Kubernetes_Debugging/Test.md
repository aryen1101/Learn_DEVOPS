# Session 14 - Kubernetes Troubleshooting (Practice)

## 1. kubectl get

![kubectl get](image.png)
![kubectl get](image-1.png)

## 2. kubectl describe

![kubectl describe](image-2.png)

## 3. kubectl logs

![kubectl logs](image-3.png)

## 4. kubectl exec

![kubectl exec](image-4.png)

## 5. Events

![kubectl events](image-5.png)
![kubectl events](image-6.png)
![kubectl delete pod](image-7.png)
![kubectl get events --sort-by](image-8.png)

## 6. CrashLoopBackOff

![CrashLoopBackOff](image-9.png)

## 7. ImagePullBackOff

![ImagePullBackOff](image-10.png)

## 8. Pending Pods

![Pending Pods](image-11.png)

## 9. Service and DNS Troubleshooting

![Service troubleshooting](image-12.png)
![DNS troubleshooting](image-13.png)

---

Mini-Project ->
![alt text](image-14.png)
![alt text](image-15.png)
![alt text](image-16.png)
![alt text](image-17.png)
![alt text](image-18.png)

Question 1: What is the Pod status?
Answer: ImagePullBackOff

Question 2: What is the actual error?
Answer: ImagePullBackOff -> Kubenetes asked for this image but it does not exist in DockerHub.

Question 3: Which command helped you find the reason?
Answer: kubectl events

Question 4: What is wrong with the image?
Answer: The image name nginx is correct, but the tag this-tag-does-not-exist is wrong. There is no such version of nginx on Docker Hub, so the image can never be downloaded.

Question 5: How would you fix it?
Answer: Change the tag to a real one.


# Task

## Events vs Logs

| | Events | Logs |
|---|---|---|
| Who writes it | Kubernetes itself | The app running inside the container |
| What it tells | What Kubernetes tried to do (schedule, pull image, start, kill) | What the app printed (errors, requests, stack traces) |
| Command | `kubectl get events` / `kubectl describe pod <pod>` | `kubectl logs <pod>` |
| Works when pod is not running? | Yes, that is exactly when it helps (Pending, ImagePullBackOff) | No, container must have started at least once |
| Kept for how long | About 1 hour, then gone | As long as the container exists (`--previous` for the last crashed one) |
| Use it for | "Why is my pod not starting?" | "Why is my app crashing or misbehaving?" |

Simple rule: pod not starting -> check Events. Pod starting but breaking -> check Logs.
