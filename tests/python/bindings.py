"""Conveniences for the compiler's ctypes bindings, using the Godot library.

Fixtures own their values; field/container views keep the owner alive. Native
assignment performs deep copies, including vectors and suspended action frames.
No game rules or test assertions are implemented in this adapter.
"""
import ctypes
import operator
import re
from pathlib import Path
import importlib.util
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def raw(value):
    return value.native if isinstance(value, Value) else value


def wrap(value, owners=()):
    if isinstance(value, ctypes._Pointer):
        value = value.contents
    if isinstance(value, (ctypes.Structure, ctypes.Array)):
        return Value(value, owners)
    if isinstance(value, ctypes._SimpleCData):
        return value.value
    return value


def copy(value):
    """Explicit Rulebook value copy; Python assignment otherwise aliases."""
    if isinstance(value, Value):
        return wrap(value.native.clone(), value.owners)
    return value


class Value:
    def __init__(self, native, owners=()):
        object.__setattr__(self, "native", native)
        object.__setattr__(self, "owners", owners)

    def __getattr__(self, name):
        attr = getattr(self.native, name)
        if callable(attr):
            def invoke(*args):
                result = rl.call(name, self, *args)
                return wrap(result, (self, *args))
            return invoke
        return wrap(attr, (self,))

    def __setattr__(self, name, value):
        fields = dict(self.native._fields_)
        target = fields[name]
        if issubclass(target, ctypes.Structure):
            assign(wrap(getattr(self.native, name), (self,)), value)
        else:
            setattr(self.native, name, raw(value))

    def __getitem__(self, index):
        if isinstance(self.native, ctypes.Array):
            return wrap(self.native[index], (self,))
        return self.get(index)

    def __setitem__(self, index, value):
        if isinstance(self.native, ctypes.Array):
            target = wrap(self.native[index], (self,))
            if isinstance(target, Value):
                assign(target, value)
            else:
                self.native[index] = raw(value)
        elif hasattr(self.native, "set"):
            self.set(index, value)
        else:
            assign(self[index], value)

    def __bool__(self):
        raise TypeError("Use an explicit comparison for a Rulebook value")

    def __int__(self):
        return int(self.native.value)

    def __eq__(self, other):
        if hasattr(self.native, "equal"):
            try:
                return self.equal(other)
            except TypeError:
                pass
        if hasattr(self.native, "value"):
            return self.native.value == (other.native.value if isinstance(other, Value) else other)
        raise TypeError(f"No equality binding for {type(self.native).__name__}")

    def __ne__(self, other):
        return not self == other

    def __repr__(self):
        return repr(self.native)


def assign(target, value):
    """Use native assignment rather than a shallow ctypes field copy."""
    native, source = raw(target), raw(value)
    if type(native) is type(source):
        name = type(native).__name__
        function = getattr(rl.module.lib, f"rl_m_assign__{name}_{name}")
        function(ctypes.byref(native), ctypes.byref(source))
    elif hasattr(native, "assign"):
        native.assign(source)
    else:
        raise TypeError(f"Cannot assign {type(source).__name__} to {type(native).__name__}")


def _binary(name, primitive):
    def apply(self, other):
        if hasattr(self.native, name):
            try:
                return getattr(self, name)(other)
            except TypeError:
                pass
        return primitive(int(self), int(other) if isinstance(other, Value) else other)
    return apply


for _dunder, _name, _op in [
    ("__add__", "add", operator.add), ("__sub__", "sub", operator.sub),
    ("__mul__", "mul", operator.mul), ("__floordiv__", "div", operator.floordiv),
    ("__mod__", "mod", operator.mod), ("__lt__", "less", operator.lt),
    ("__le__", "less_equal", operator.le), ("__gt__", "greater", operator.gt),
    ("__ge__", "greater_equal", operator.ge),
]:
    setattr(Value, _dunder, _binary(_name, _op))


class Symbols:
    def is_variant(self, value, spelling):
        return value.native[self.type(spelling)] is not None

    def variant(self, value, spelling):
        return wrap(value.native[self.type(spelling)], (value,))

    def load(self, wrapper, library):
        # The generated wrapper assumes a sibling lib.so. Use the exact
        # Rulebook library linked by Godot instead; never copy/rebuild it.
        spec = importlib.util.spec_from_file_location("fourhammer_rules", wrapper)
        module = importlib.util.module_from_spec(spec)
        loader = ctypes.CDLL
        with patch.object(ctypes, "CDLL", side_effect=lambda *a, **kw: loader(str(library), **kw)):
            spec.loader.exec_module(module)
        self.module = module
        self.aliases = {}
        self.constants = {}
        for path in (ROOT / "src").glob("*.rl"):
            text = path.read_text()
            self.aliases.update(re.findall(r"^using (\w+) = (.+)$", text, re.M))
            self.constants.update(re.findall(r"^const (\w+) = ([^#\n]+)", text, re.M))

    def number(self, expression):
        # Only integer arithmetic and named source constants are admitted.
        import ast
        def evaluate(node):
            if isinstance(node, ast.Constant) and type(node.value) is int:
                return node.value
            if isinstance(node, ast.Name):
                return self.number(self.constants[node.id])
            if isinstance(node, ast.BinOp):
                operations = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul}
                return operations[type(node.op)](evaluate(node.left), evaluate(node.right))
            raise ValueError(f"Unsupported constant: {expression}")
        return evaluate(ast.parse(expression.strip(), mode="eval").body)

    def type(self, spelling):
        if hasattr(self.module, spelling):
            return getattr(self.module, spelling)
        spelling = self.aliases.get(spelling, spelling).strip()
        if spelling in self.aliases:
            return self.type(spelling)
        array = re.fullmatch(r"(.+)\[(.+)\]", spelling)
        if array:
            return self.type(array[1]) * self.number(array[2])
        if spelling == "Bool":
            return ctypes.c_bool
        if spelling == "Int":
            return ctypes.c_longlong
        generic = re.fullmatch(r"(\w+)<(.+)>", spelling)
        if generic:
            parts = []
            for arg in generic[2].split(","):
                try:
                    parts.append(str(self.number(arg)))
                except (KeyError, ValueError):
                    parts.append("int64_t" if arg.strip() == "Int" else self.type(arg.strip()).__name__)
            spelling = generic[1] + "T" + "T".join(parts) + "T"
        return getattr(self.module, spelling)

    def new(self, spelling):
        return wrap(self.type(spelling)())

    def __getattr__(self, name):
        if name in self.constants:
            return self.number(name)
        if name in self.aliases:
            return lambda: self.new(name)
        item = getattr(self.module, name)
        if isinstance(item, type) and issubclass(item, ctypes.Structure):
            return Type(item)
        def invoke(*args):
            return wrap(self.call(name, *args), args)
        return invoke

    def call(self, name, *args):
        arguments = [raw(arg) for arg in args]
        # Generated dispatch tests fixed arrays as Python lists, while the
        # actual ABI requires ctypes arrays. Select its typed wrapper directly.
        for function in self.module.wrappers[name]:
            signature = self.module.signatures[function][1:]
            if len(signature) != len(arguments):
                continue
            if all((expected is list and isinstance(actual, ctypes.Array)) or
                   (isinstance(actual, expected) and not (expected is int and isinstance(actual, bool)))
                   for expected, actual in zip(signature, arguments)):
                if list in signature and not self.array_signature_matches(function, signature, arguments):
                    continue
                return function(*arguments)
        raise TypeError(f"No {name} binding accepts {[type(arg).__name__ for arg in arguments]}")

    @staticmethod
    def array_signature_matches(function, signature, arguments):
        # RLC's signature table loses array sizes/types (it records only list).
        # The exported symbol retains both: never pass a short/wrong array to C.
        primitives = {int: 'int64_t', bool: 'bool', float: 'double', str: 'strlit',
                      ctypes.c_longlong: 'int64_t', ctypes.c_bool: 'bool', ctypes.c_double: 'double'}
        encoded = []
        for expected, actual in zip(signature, arguments):
            if expected is list:
                element = actual._type_
                encoded.append(f'{primitives.get(element, element.__name__)}_{actual._length_}')
            else:
                encoded.append(primitives.get(expected, expected.__name__))
        parameters = function.__name__.split('__', 1)[1]
        wanted = '_'.join(encoded)
        return parameters == wanted or parameters.startswith(wanted + '_r_')


class Type:
    def __init__(self, native):
        self.native = native

    def __call__(self):
        return wrap(self.native())

    def __getattr__(self, name):
        return lambda: wrap(getattr(self.native, name)())


rl = Symbols()
