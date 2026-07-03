from airflow.decorators import dag, task

@dag()
def operator_python_decorator():
    @task
    def python(param1):
        print("ini adalah operator python dengan decorator")
        print(param1)

    python(
        param1 = "ini adalah param1"
    )

operator_python_decorator()
