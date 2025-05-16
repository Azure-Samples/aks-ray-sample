from ray.job_submission import JobSubmissionClient

client = JobSubmissionClient("http://127.0.0.1:8265")

kick_off_gpt_tuning = (
    # Clone ray. If ray is already present, don't clone again.
    "git clone -b nearora/ray_abs https://github.com/nearora-msft/ray || true;"
    # Run the benchmark.
    " python ray/release/air_tests/air_benchmarks/workloads/tune_gpt2.py"
)

submission_id = client.submit_job(
    entrypoint=kick_off_gpt_tuning,
)

print("Use the following command to follow this Job's logs:")
print(f"ray job logs '{submission_id}' --follow")