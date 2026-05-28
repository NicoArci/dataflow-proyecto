"""
Carga los CSVs de Olist en PostgreSQL.
Borra los datos de prueba previos y carga el dataset completo en chunks.
Orden de carga respeta las FK: customers → sellers → products →
                                orders → order_items → order_reviews
"""

import pandas as pd
from sqlalchemy import create_engine, text
from pathlib import Path
from tqdm import tqdm

# ── Conexión ──────────────────────────────────────────────────────────────────
DB_URL  = "postgresql+psycopg2://dataflow_user:dataflow_pass@localhost:5433/dataflow"
engine  = create_engine(DB_URL, future=True)
DATA    = Path(__file__).parent
CHUNK   = 5_000

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_chunks(df: pd.DataFrame, table: str) -> int:
    """Inserta df en la tabla PostgreSQL en bloques de CHUNK filas."""
    total = len(df)
    with tqdm(total=total, desc=f"  {table}", unit="filas", leave=False) as bar:
        for start in range(0, total, CHUNK):
            chunk = df.iloc[start : start + CHUNK]
            chunk.to_sql(table, engine, if_exists="append", index=False, method="multi")
            bar.update(len(chunk))
    return total


def ids_en_db(table: str, col: str) -> set:
    with engine.connect() as conn:
        rows = conn.execute(text(f"SELECT {col} FROM {table}"))
        return {r[0] for r in rows}


# ── Paso 0: vaciar tablas (en orden inverso a las FK) ─────────────────────────

def truncate_all() -> None:
    with engine.begin() as conn:
        conn.execute(text(
            "TRUNCATE order_reviews, order_items, orders, "
            "products, sellers, customers RESTART IDENTITY CASCADE"
        ))
    print("Tablas vaciadas.\n")


# ── Loaders por tabla ─────────────────────────────────────────────────────────

def load_customers() -> int:
    df = pd.read_csv(DATA / "olist_customers_dataset.csv")
    df = df.rename(columns={
        "customer_zip_code_prefix": "zip_code",
        "customer_city":            "city",
        "customer_state":           "state",
    })[["customer_id", "customer_unique_id", "zip_code", "city", "state"]]
    df.drop_duplicates("customer_id", inplace=True)
    return load_chunks(df, "customers")


def load_sellers() -> int:
    df = pd.read_csv(DATA / "olist_sellers_dataset.csv")
    df = df.rename(columns={
        "seller_zip_code_prefix": "zip_code",
        "seller_city":            "city",
        "seller_state":           "state",
    })[["seller_id", "zip_code", "city", "state"]]
    df.drop_duplicates("seller_id", inplace=True)
    return load_chunks(df, "sellers")


def load_products() -> int:
    df = pd.read_csv(DATA / "olist_products_dataset.csv")
    df = df.rename(columns={
        "product_category_name":      "category_name",
        "product_name_lenght":        "name_length",       # typo original del dataset
        "product_description_lenght": "description_length",
        "product_photos_qty":         "photos_qty",
        "product_weight_g":           "weight_g",
        "product_length_cm":          "length_cm",
        "product_height_cm":          "height_cm",
        "product_width_cm":           "width_cm",
    })[["product_id", "category_name", "name_length", "description_length",
        "photos_qty", "weight_g", "length_cm", "height_cm", "width_cm"]]
    df.drop_duplicates("product_id", inplace=True)
    return load_chunks(df, "products")


def load_orders() -> int:
    ts_cols = [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ]
    df = pd.read_csv(DATA / "olist_orders_dataset.csv", parse_dates=ts_cols)
    df = df.rename(columns={
        "order_purchase_timestamp":      "purchase_timestamp",
        "order_approved_at":             "approved_at",
        "order_delivered_carrier_date":  "carrier_delivery_timestamp",
        "order_delivered_customer_date": "customer_delivery_timestamp",
        "order_estimated_delivery_date": "estimated_delivery_date",
    })[["order_id", "customer_id", "order_status", "purchase_timestamp",
        "approved_at", "carrier_delivery_timestamp",
        "customer_delivery_timestamp", "estimated_delivery_date"]]
    df.drop_duplicates("order_id", inplace=True)
    # solo órdenes cuyo customer existe
    valid = ids_en_db("customers", "customer_id")
    df = df[df["customer_id"].isin(valid)]
    return load_chunks(df, "orders")


def load_order_items() -> int:
    df = pd.read_csv(
        DATA / "olist_order_items_dataset.csv",
        parse_dates=["shipping_limit_date"],
    )
    df = df.rename(columns={
        "order_item_id":      "item_seq",
        "shipping_limit_date": "shipping_limit",
    })[["order_id", "item_seq", "product_id", "seller_id",
        "shipping_limit", "price", "freight_value"]]
    # filtrar FK inválidas
    valid_orders   = ids_en_db("orders",   "order_id")
    valid_products = ids_en_db("products", "product_id")
    valid_sellers  = ids_en_db("sellers",  "seller_id")
    df = df[
        df["order_id"].isin(valid_orders) &
        df["product_id"].isin(valid_products) &
        df["seller_id"].isin(valid_sellers)
    ]
    return load_chunks(df, "order_items")


def load_order_reviews() -> int:
    ts_cols = ["review_creation_date", "review_answer_timestamp"]
    df = pd.read_csv(DATA / "olist_order_reviews_dataset.csv", parse_dates=ts_cols)
    df = df.rename(columns={
        "review_comment_title":   "comment_title",
        "review_comment_message": "comment_message",
        "review_creation_date":   "creation_date",
        "review_answer_timestamp":"answer_timestamp",
    })[["review_id", "order_id", "review_score", "comment_title",
        "comment_message", "creation_date", "answer_timestamp"]]
    # el CSV tiene review_ids duplicados; conservar el primero
    df.drop_duplicates("review_id", inplace=True)
    valid = ids_en_db("orders", "order_id")
    df = df[df["order_id"].isin(valid)]
    return load_chunks(df, "order_reviews")


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    truncate_all()

    pasos = [
        ("customers",     load_customers),
        ("sellers",       load_sellers),
        ("products",      load_products),
        ("orders",        load_orders),
        ("order_items",   load_order_items),
        ("order_reviews", load_order_reviews),
    ]

    counts: dict[str, int] = {}
    for nombre, fn in pasos:
        print(f"Cargando {nombre}...")
        counts[nombre] = fn()
        print(f"  OK {counts[nombre]:>10,} filas")

    print("\n" + "=" * 38)
    print(f"{'Tabla':<20} {'Filas':>10}")
    print("-" * 38)
    for tabla, n in counts.items():
        print(f"  {tabla:<18} {n:>10,}")
    print("=" * 38)
