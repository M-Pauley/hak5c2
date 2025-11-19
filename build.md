# Pushing to Docker Hub

---

Example run for **release 3.5.2**, following the exact tagging pattern you used before.

* **RELEASE = 3.5.2-stable**
* **TAG = 3.5.2-amd64**
* **Secondary tag = 3.5.2**
* **Latest tag = latest**

---

# ✅ Commands for building & pushing version **3.5.2**

### 1. Log in (same as before)

```bash
docker login
```

### 2. Build the image

```bash
DOCKER_BUILDKIT=1 docker build \
  --build-arg RELEASE=3.5.2-stable \
  --build-arg TARGET=amd64_linux \
  -t joshuapfritz/hak5c2:3.5.2-amd64 .
```

### 3. Tag the architecture-specific image as the generic version

```bash
docker tag joshuapfritz/hak5c2:3.5.2-amd64 joshuapfritz/hak5c2:3.5.2
```

### 4. Tag it as `latest`

```bash
docker tag joshuapfritz/hak5c2:3.5.2-amd64 joshuapfritz/hak5c2:latest
```

### 5. Push all tags

```bash
docker push joshuapfritz/hak5c2:3.5.2-amd64
docker push joshuapfritz/hak5c2:3.5.2
docker push joshuapfritz/hak5c2:latest
```

---

# 🔁 Optional: Make this zero-mistake with variables

Avoid typos each release:

```bash
export VER=3.5.2
export REL="${VER}-stable"
export TAG="joshuapfritz/hak5c2"

DOCKER_BUILDKIT=1 docker build \
  --build-arg RELEASE=$REL \
  --build-arg TARGET=amd64_linux \
  -t $TAG:${VER}-amd64 .

docker tag $TAG:${VER}-amd64 $TAG:$VER
docker tag $TAG:${VER}-amd64 $TAG:latest

docker push $TAG:${VER}-amd64
docker push $TAG:$VER
docker push $TAG:latest
```
