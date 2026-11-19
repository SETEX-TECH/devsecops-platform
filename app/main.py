from fastapi import FastAPI

app = FastAPI(title="devsecops-app")


@app.get("/")
def root():
    return {"message": "Hello DevSecOps"}


@app.get("/health")
def health():
    return {"status": "ok"}
# test
