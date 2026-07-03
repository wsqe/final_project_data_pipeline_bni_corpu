from airflow.decorators import dag
from airflow.operators.python import PythonOperator

def print_python(param1):
    print("ini adalah operator python")
    print(param1)

@dag()
def operator_python_parameter():
    python = PythonOperator(
        task_id         = "python",
        python_callable = print_python,
        op_kwargs       = {
            "param1": "ini adalah param1"
        },
    )

    python

operator_python_parameter()
