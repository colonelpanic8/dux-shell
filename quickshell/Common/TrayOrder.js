.pragma library

function sorted(items, priorityOf, savedOrder, keyOf) {
    const saved = new Map(savedOrder.map((key, index) => [key, index]));
    const position = item => saved.has(keyOf(item)) ? saved.get(keyOf(item)) : 10000 + items.indexOf(item);
    return [...items].sort((a, b) => position(a) - position(b)).sort((a, b) => priorityOf(b) - priorityOf(a));
}
