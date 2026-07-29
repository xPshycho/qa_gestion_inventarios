import { loadAuthRuntimeConfig } from './auth.config';

describe('loadAuthRuntimeConfig', () => {
  it('acepta una configuracion runtime completa', async () => {
    spyOn(window, 'fetch').and.resolveTo(new Response(JSON.stringify({
      url: 'http://localhost:8081',
      realm: 'inventory',
      clientId: 'inventory-frontend'
    }), { status: 200 }));

    await expectAsync(loadAuthRuntimeConfig()).toBeResolvedTo({
      url: 'http://localhost:8081',
      realm: 'inventory',
      clientId: 'inventory-frontend'
    });
    expect(window.fetch).toHaveBeenCalledWith('/auth-config.json', {
      cache: 'no-store'
    });
  });

  it('rechaza respuestas HTTP fallidas', async () => {
    spyOn(window, 'fetch').and.resolveTo(new Response('', { status: 502 }));

    await expectAsync(loadAuthRuntimeConfig()).toBeRejectedWithError(
      'No se pudo cargar la configuración de autenticación (502).'
    );
  });

  [
    null,
    'invalid',
    {},
    { url: ' ', realm: 'inventory', clientId: 'inventory-frontend' },
    { url: 'http://keycloak', realm: 42, clientId: 'inventory-frontend' },
    { url: 'http://keycloak', realm: 'inventory', clientId: '' }
  ].forEach((invalidConfig) => {
    it(`rechaza configuracion invalida: ${JSON.stringify(invalidConfig)}`, async () => {
      spyOn(window, 'fetch').and.resolveTo(new Response(
        JSON.stringify(invalidConfig),
        { status: 200 }
      ));

      await expectAsync(loadAuthRuntimeConfig()).toBeRejectedWithError(
        'La configuración de autenticación no es válida.'
      );
    });
  });
});
