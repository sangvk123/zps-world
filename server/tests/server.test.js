const PlayerRegistry = require('../src/player-registry');

describe('PlayerRegistry', () => {
  let registry;
  const mockWs = { send: jest.fn(), readyState: 1 };

  beforeEach(() => { registry = new PlayerRegistry(); });

  test('add and get player', () => {
    registry.add('p1', { ws: mockWs, x: 100, y: 200, avatar: {}, zone: 'main' });
    const p = registry.get('p1');
    expect(p.x).toBe(100);
    expect(p.y).toBe(200);
    expect(p.zone).toBe('main');
  });

  test('updatePosition changes x and y', () => {
    registry.add('p1', { ws: mockWs, x: 0, y: 0, avatar: {}, zone: 'main' });
    registry.updatePosition('p1', 300, 400);
    const p = registry.get('p1');
    expect(p.x).toBe(300);
    expect(p.y).toBe(400);
  });

  test('remove deletes player', () => {
    registry.add('p1', { ws: mockWs, x: 0, y: 0, avatar: {}, zone: 'main' });
    registry.remove('p1');
    expect(registry.get('p1')).toBeUndefined();
  });

  test('getRoster excludes self', () => {
    registry.add('p1', { ws: mockWs, x: 10, y: 20, avatar: { hair: 'short' }, zone: 'main', status: 'available', statusMessage: '' });
    registry.add('p2', { ws: mockWs, x: 30, y: 40, avatar: { hair: 'long' }, zone: 'main', status: 'available', statusMessage: '' });
    const roster = registry.getRoster('p1');
    expect(roster).toHaveLength(1);
    expect(roster[0].id).toBe('p2');
  });

  test('updateStatus updates status and message', () => {
    registry.add('p1', { ws: mockWs, x: 0, y: 0, avatar: {}, zone: 'main', status: 'available', statusMessage: '' });
    registry.updateStatus('p1', 'busy', 'In meeting');
    const p = registry.get('p1');
    expect(p.status).toBe('busy');
    expect(p.statusMessage).toBe('In meeting');
  });
});

const RoomManager = require('../src/room-manager');

describe('RoomManager', () => {
  let registry, rooms;
  const makeWs = () => ({ send: jest.fn(), readyState: 1 });

  beforeEach(() => {
    registry = new PlayerRegistry();
    rooms = new RoomManager(registry);
  });

  test('join adds player to zone', () => {
    registry.add('p1', { ws: makeWs(), x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    const zones = rooms.getAllZones();
    expect(zones.get('main').has('p1')).toBe(true);
  });

  test('leave removes player from zone', () => {
    registry.add('p1', { ws: makeWs(), x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    rooms.leave('p1', 'main');
    const zones = rooms.getAllZones();
    expect(zones.get('main')?.has('p1')).toBeFalsy();
  });

  test('broadcast sends to all in zone except sender', () => {
    const ws1 = makeWs();
    const ws2 = makeWs();
    registry.add('p1', { ws: ws1, x: 0, y: 0, avatar: {}, zone: 'main' });
    registry.add('p2', { ws: ws2, x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    rooms.join('p2', 'main');
    rooms.broadcast('main', { type: 'test' }, 'p1');
    expect(ws2.send).toHaveBeenCalledWith(JSON.stringify({ type: 'test' }));
    expect(ws1.send).not.toHaveBeenCalled();
  });

  test('broadcastToZone sends to everyone in zone', () => {
    const ws1 = makeWs();
    registry.add('p1', { ws: ws1, x: 0, y: 0, avatar: {}, zone: 'main' });
    rooms.join('p1', 'main');
    rooms.broadcastToZone('main', { type: 'tick' });
    expect(ws1.send).toHaveBeenCalledWith(JSON.stringify({ type: 'tick' }));
  });
});
