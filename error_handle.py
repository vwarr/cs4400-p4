from mysql.connector import pooling, errorcode, DatabaseError, IntegrityError

def handle_db_error(e):
    if hasattr(e, 'msg') and isinstance(e.msg, str):
        return e.msg;
    if isinstance(e, IntegrityError):
        if e.errno == errorcode.ER_DUP_ENTRY:
            return "Duplicate entry."
        if e.errno in (errorcode.ER_NO_REFERENCED_ROW_2, errorcode.ER_NO_REFERENCED_ROW):
            return "Invalid reference to another record."
    return "Unexpected database behavior. Please check your inputs and try again."