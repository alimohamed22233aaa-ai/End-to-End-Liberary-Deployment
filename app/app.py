import os
from functools import wraps

from flask import (
    Flask, abort, flash, redirect, render_template, request, session, url_for,
)
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)

# --- Configuration -----------------------------------------------------------
# In production (Docker/CI), set SECRET_KEY as an environment variable.
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-only-change-me")
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///library.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


# --- Models ------------------------------------------------------------------
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)


class Book(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    author = db.Column(db.String(150), nullable=False)
    cover_image_url = db.Column(db.String(300), nullable=False)
    price = db.Column(db.Float, nullable=False)
    available_quantity = db.Column(db.Integer, nullable=False, default=0)


# --- Helpers -----------------------------------------------------------------
def login_required(view):
    """Send visitors who are not logged in to the login page."""
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            flash("Please log in to buy or borrow books.", "warning")
            return redirect(url_for("login"))
        return view(*args, **kwargs)
    return wrapped


# --- Routes ------------------------------------------------------------------
@app.route("/")
def index():
    books = Book.query.order_by(Book.title).all()
    return render_template("index.html", books=books)


def take_copy(book_id, verb_past):
    book = db.session.get(Book, book_id)
    if book is None:
        abort(404)
    if book.available_quantity < 1:
        flash(f'Sorry, "{book.title}" is out of stock.', "danger")
    else:
        book.available_quantity -= 1
        db.session.commit()
        flash(f'You {verb_past} "{book.title}".', "success")
    return redirect(url_for("index"))


@app.route("/buy/<int:book_id>", methods=["POST"])
@login_required
def buy(book_id):
    return take_copy(book_id, "bought")


@app.route("/borrow/<int:book_id>", methods=["POST"])
@login_required
def borrow(book_id):
    return take_copy(book_id, "borrowed")


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        name = request.form.get("name", "").strip()
        email = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")
        confirm_password = request.form.get("confirm_password", "")

        if not name or not email or not password:
            flash("Please fill in all fields.", "danger")
        elif len(password) < 8:
            flash("Password must be at least 8 characters.", "danger")
        elif password != confirm_password:
            flash("Passwords do not match.", "danger")
        elif User.query.filter_by(email=email).first():
            flash("An account with this email already exists.", "danger")
        else:
            user = User(
                name=name,
                email=email,
                password_hash=generate_password_hash(password),
            )
            db.session.add(user)
            db.session.commit()
            flash("Account created. You can log in now.", "success")
            return redirect(url_for("login"))

    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")

        user = User.query.filter_by(email=email).first()
        if user and check_password_hash(user.password_hash, password):
            session.clear()
            session["user_id"] = user.id
            session["user_name"] = user.name
            return redirect(url_for("index"))

        flash("Incorrect email or password.", "danger")

    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("You have been logged out.", "info")
    return redirect(url_for("login"))


# --- Database setup ----------------------------------------------------------
def seed_books():
    """Insert sample books only when the table is empty."""
    if Book.query.count() > 0:
        return

    def cover(isbn):
        # Real cover images served by Open Library (free, no API key)
        return f"https://covers.openlibrary.org/b/isbn/{isbn}-L.jpg"

    db.session.add_all(
        [
            Book(title="The Pragmatic Programmer", author="Andrew Hunt & David Thomas",
                 cover_image_url=cover("9780135957059"), price=39.99, available_quantity=12),
            Book(title="Clean Code", author="Robert C. Martin",
                 cover_image_url=cover("9780132350884"), price=34.50, available_quantity=7),
            Book(title="The Phoenix Project", author="Gene Kim",
                 cover_image_url=cover("9781942788294"), price=24.00, available_quantity=3),
            Book(title="Site Reliability Engineering", author="Betsy Beyer",
                 cover_image_url=cover("9781491929124"), price=44.00, available_quantity=5),
            Book(title="Designing Data-Intensive Applications", author="Martin Kleppmann",
                 cover_image_url=cover("9781449373320"), price=49.95, available_quantity=9),
            Book(title="Refactoring", author="Martin Fowler",
                 cover_image_url=cover("9780134757599"), price=42.00, available_quantity=2),
            Book(title="Continuous Delivery", author="Jez Humble & David Farley",
                 cover_image_url=cover("9780321601919"), price=38.75, available_quantity=6),
            Book(title="Accelerate", author="Nicole Forsgren",
                 cover_image_url=cover("9781942788331"), price=29.99, available_quantity=10),
        ]
    )
    db.session.commit()


# Runs on import, so it also works under gunicorn inside Docker.
with app.app_context():
    db.create_all()
    seed_books()


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=os.environ.get("FLASK_DEBUG") == "1",
    )
